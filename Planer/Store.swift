import SwiftUI

enum SyncStatus: Equatable {
    case notConfigured, idle, syncing, ok
    case error(String)
}

/// Hält alle Daten, speichert sie lokal (offline nutzbar) und gleicht sie mit dem Raspberry Pi ab.
@MainActor @Observable
final class Store {
    var tasks: [TaskItem] = []
    var lists: [TaskList] = []
    var syncStatus: SyncStatus = .idle
    var lastSync: Date?

    var serverURL: String = UserDefaults.standard.string(forKey: "serverURL") ?? "" {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    var token: String = UserDefaults.standard.string(forKey: "token") ?? "" {
        didSet { UserDefaults.standard.set(token, forKey: "token") }
    }

    private var lastRev = 0
    private var isSyncing = false
    private var needsResync = false
    private var pendingSync: Task<Void, Never>?

    init() {
        load()
        Reminders.setup()
        Reminders.reschedule(tasks)
        WidgetExport.update(store: self)
    }

    // MARK: - Abfragen

    var visibleLists: [TaskList] {
        lists.filter { !$0.deleted }.sorted { $0.createdAt < $1.createdAt }
    }

    func list(_ id: String?) -> TaskList? {
        guard let id else { return nil }
        return lists.first { $0.id == id && !$0.deleted }
    }

    func listName(_ id: String?) -> String { list(id)?.name ?? "Eingang" }

    func title(for filter: Filter) -> String {
        switch filter {
        case .today: "Heute"
        case .tomorrow: "Morgen"
        case .week: "Nächste 7 Tage"
        case .inbox: "Eingang"
        case .all: "Alle"
        case .completed: "Erledigt"
        case .list(let id): list(id)?.name ?? "Liste"
        }
    }

    static func order(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let da = a.dueDate ?? .distantFuture, db = b.dueDate ?? .distantFuture
        if da != db { return da < db }
        if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
        return a.createdAt < b.createdAt
    }

    private static func byPriority(_ a: TaskItem, _ b: TaskItem) -> Bool {
        if a.priority != b.priority { return a.priority.rawValue > b.priority.rawValue }
        return order(a, b)
    }

    func sections(for filter: Filter, search: String = "", sortByPriority: Bool = false) -> [TaskSection] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let all = tasks.filter {
            !$0.deleted && (q.isEmpty || $0.title.lowercased().contains(q) || $0.notes.lowercased().contains(q)
                            || $0.tags.contains { $0.lowercased().contains(q) })
        }
        let open = all.filter { !$0.isCompleted }.sorted(by: sortByPriority ? Self.byPriority : Self.order)
        let done = all.filter(\.isCompleted)
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let today = Date().startOfDay
        var out: [TaskSection] = []
        func add(_ title: String, _ items: [TaskItem], completed: Bool = false) {
            if !items.isEmpty { out.append(TaskSection(title: title, tasks: items, isCompletedSection: completed)) }
        }
        func due(_ items: [TaskItem], from: Date, days: Int = 1) -> [TaskItem] {
            let end = from.addingDays(days)
            return items.filter { t in t.dueDate.map { $0 >= from && $0 < end } ?? false }
        }
        let overdue = open.filter { ($0.dueDate ?? .distantFuture) < today }

        switch filter {
        case .today:
            add("Überfällig", overdue)
            add("Heute", due(open, from: today))
            add("Erledigt", done.filter { ($0.completedAt ?? .distantPast) >= today }, completed: true)
        case .tomorrow:
            add("Morgen", due(open, from: today.addingDays(1)))
            add("Erledigt", done.filter { t in t.dueDate.map { Calendar.current.isDateInTomorrow($0) } ?? false }, completed: true)
        case .week:
            add("Überfällig", overdue)
            for offset in 0..<7 {
                let day = today.addingDays(offset)
                let title = switch offset {
                case 0: "Heute"
                case 1: "Morgen"
                default: day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(german))
                }
                add(title, due(open, from: day))
            }
        case .inbox:
            add("Offen", open.filter { list($0.listID) == nil })
            add("Erledigt", done.filter { list($0.listID) == nil }, completed: true)
        case .all:
            add("Überfällig", overdue)
            add("Offen", open.filter { ($0.dueDate ?? .distantFuture) >= today })
        case .completed:
            add("Erledigt", Array(done.prefix(300)), completed: true)
        case .list(let id):
            add("Offen", open.filter { $0.listID == id })
            add("Erledigt", done.filter { $0.listID == id }, completed: true)
        }
        return out
    }

    func openCount(for filter: Filter) -> Int {
        sections(for: filter).filter { !$0.isCompletedSection }.reduce(0) { $0 + $1.tasks.count }
    }

    /// Alle Aufgaben mit Datum, nach Tag gruppiert (für den Kalender).
    func tasksByDay() -> [Date: [TaskItem]] {
        var map: [Date: [TaskItem]] = [:]
        for t in tasks where !t.deleted {
            guard let due = t.dueDate else { continue }
            let start = due.startOfDay
            let end = (t.endDate ?? due).startOfDay
            var day = start
            var guardCount = 0
            while day <= end && guardCount < 62 {
                map[day, default: []].append(t)
                day = day.addingDays(1)
                guardCount += 1
            }
            // Künftige Termine wiederkehrender Aufgaben im Kalender anzeigen.
            if let rule = t.recurrence, !t.isCompleted {
                let horizon = Date().addingDays(120)
                var next = rule.fromCompletion ? due : rule.next(after: due)
                var count = 0
                while !rule.fromCompletion && next < horizon && count < 60 {
                    map[next.startOfDay, default: []].append(t)
                    next = rule.next(after: next)
                    count += 1
                }
            }
        }
        return map.mapValues { items in
            items.sorted { a, b in
                if a.isCompleted != b.isCompleted { return !a.isCompleted }
                if a.hasTime != b.hasTime { return !a.hasTime }
                return Self.order(a, b)
            }
        }
    }

    // MARK: - Änderungen

    func newTask(title: String = "", filter: Filter?, day: Date? = nil) -> TaskItem {
        var t = TaskItem(title: title)
        if let day { t.dueDate = day.startOfDay; return t }
        switch filter {
        case .today, .week: t.dueDate = Date().startOfDay
        case .tomorrow: t.dueDate = Date().startOfDay.addingDays(1)
        case .list(let id): t.listID = id
        default: break
        }
        return t
    }

    func upsert(_ task: TaskItem) {
        var t = task
        t.updatedAt = nowMillis()
        t.dirty = true
        if let i = tasks.firstIndex(where: { $0.id == t.id }) { tasks[i] = t } else { tasks.append(t) }
        changed()
    }

    func delete(_ task: TaskItem) {
        var t = task
        t.deleted = true
        upsert(t)
    }

    /// Abhaken bzw. wieder öffnen. Wiederkehrende Aufgaben springen auf den nächsten Termin;
    /// der erledigte Termin bleibt als eigener Eintrag unter „Erledigt“ erhalten.
    @discardableResult
    func toggle(_ task: TaskItem) -> TaskItem {
        var t = task
        if !t.isCompleted, let rule = t.recurrence, let due = t.dueDate {
            var record = t
            record.id = UUID().uuidString
            record.recurrence = nil
            record.isCompleted = true
            record.completedAt = Date()
            record.createdAt = Date()
            upsert(record)

            var next = rule.next(after: due)
            if !rule.fromCompletion {
                let today = Date().startOfDay
                var steps = 0
                while next < today && steps < 5000 { next = rule.next(after: next); steps += 1 }
            }
            if let end = t.endDate { t.endDate = end.addingTimeInterval(next.timeIntervalSince(due)) }
            t.dueDate = next
            t.subtasks = t.subtasks.map { var s = $0; s.done = false; return s }
        } else {
            t.isCompleted.toggle()
            t.completedAt = t.isCompleted ? Date() : nil
        }
        upsert(t)
        return t
    }

    func upsert(_ list: TaskList) {
        var l = list
        l.updatedAt = nowMillis()
        l.dirty = true
        if let i = lists.firstIndex(where: { $0.id == l.id }) { lists[i] = l } else { lists.append(l) }
        changed()
    }

    /// Löscht die Liste; ihre Aufgaben wandern in den Eingang.
    func delete(_ list: TaskList) {
        for t in tasks where t.listID == list.id && !t.deleted {
            var moved = t
            moved.listID = nil
            upsert(moved)
        }
        var l = list
        l.deleted = true
        upsert(l)
    }

    private func changed() {
        save()
        Reminders.reschedule(tasks)
        WidgetExport.update(store: self)
        scheduleSync()
    }

    // MARK: - Lokale Speicherung

    private struct Snapshot: Codable {
        var tasks: [TaskItem]
        var lists: [TaskList]
        var lastRev: Int
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Planer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL),
              let snap = try? Self.decoder.decode(Snapshot.self, from: data) else { return }
        tasks = snap.tasks
        lists = snap.lists
        lastRev = snap.lastRev
    }

    private func save() {
        guard let data = try? Self.encoder.encode(Snapshot(tasks: tasks, lists: lists, lastRev: lastRev)) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    // MARK: - Synchronisation

    private struct WireRecord: Codable {
        var id: String
        var kind: String
        var updatedAt: Int64
        var deleted: Bool
        var data: String
    }
    private struct SyncRequest: Codable {
        var since: Int
        var changes: [WireRecord]
    }
    private struct SyncResponse: Codable {
        var rev: Int
        var changes: [WireRecord]
    }

    private var endpoint: URL? {
        var s = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s + "/sync")
    }

    /// Nach einem Serverwechsel: alles neu hochladen und komplett neu abholen.
    func resetSync() {
        lastRev = 0
        for i in tasks.indices { tasks[i].dirty = true }
        for i in lists.indices { lists[i].dirty = true }
        save()
    }

    func scheduleSync() {
        pendingSync?.cancel()
        pendingSync = Task {
            try? await Task.sleep(for: .milliseconds(800))
            if !Task.isCancelled { await sync() }
        }
    }

    func sync() async {
        guard let endpoint else { syncStatus = .notConfigured; return }
        if isSyncing { needsResync = true; return }
        isSyncing = true
        if syncStatus != .ok { syncStatus = .syncing }

        var changes: [WireRecord] = []
        func wire<T: Encodable>(_ value: T, id: String, kind: String, updatedAt: Int64, deleted: Bool) {
            guard let data = try? Self.encoder.encode(value), let s = String(data: data, encoding: .utf8) else { return }
            changes.append(WireRecord(id: id, kind: kind, updatedAt: updatedAt, deleted: deleted, data: s))
        }
        for t in tasks where t.dirty { wire(t, id: t.id, kind: "task", updatedAt: t.updatedAt, deleted: t.deleted) }
        for l in lists where l.dirty { wire(l, id: l.id, kind: "list", updatedAt: l.updatedAt, deleted: l.deleted) }

        do {
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.timeoutInterval = 10
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONEncoder().encode(SyncRequest(since: lastRev, changes: changes))
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 401 {
                syncStatus = .error("Token ist falsch")
            } else if code != 200 {
                syncStatus = .error("Serverfehler (\(code))")
            } else {
                let result = try JSONDecoder().decode(SyncResponse.self, from: data)
                apply(result, sent: Dictionary(changes.map { ($0.id, $0.updatedAt) }, uniquingKeysWith: { a, _ in a }))
                lastSync = Date()
                syncStatus = .ok
            }
        } catch {
            syncStatus = .error("Server nicht erreichbar")
        }

        isSyncing = false
        if needsResync {
            needsResync = false
            scheduleSync()
        }
    }

    private func apply(_ result: SyncResponse, sent: [String: Int64]) {
        // Was unverändert angekommen ist, gilt als synchronisiert.
        for i in tasks.indices where tasks[i].dirty && sent[tasks[i].id] == tasks[i].updatedAt { tasks[i].dirty = false }
        for i in lists.indices where lists[i].dirty && sent[lists[i].id] == lists[i].updatedAt { lists[i].dirty = false }

        var tasksChanged = false
        for record in result.changes {
            guard let data = record.data.data(using: .utf8) else { continue }
            if record.kind == "task", var remote = try? Self.decoder.decode(TaskItem.self, from: data) {
                remote.dirty = false
                if let i = tasks.firstIndex(where: { $0.id == remote.id }) {
                    if tasks[i].dirty && tasks[i].updatedAt > remote.updatedAt { continue }
                    if tasks[i] != remote { tasks[i] = remote; tasksChanged = true }
                } else {
                    tasks.append(remote)
                    tasksChanged = true
                }
            } else if record.kind == "list", var remote = try? Self.decoder.decode(TaskList.self, from: data) {
                remote.dirty = false
                if let i = lists.firstIndex(where: { $0.id == remote.id }) {
                    if lists[i].dirty && lists[i].updatedAt > remote.updatedAt { continue }
                    if lists[i] != remote { lists[i] = remote }
                } else {
                    lists.append(remote)
                }
            }
        }
        lastRev = result.rev
        save()
        if tasksChanged { Reminders.reschedule(tasks) }
        if tasksChanged || !result.changes.isEmpty { WidgetExport.update(store: self) }
    }
}
