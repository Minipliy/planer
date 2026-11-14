import Foundation

/// Daten, die die App für die Widgets bereitlegt (App Group, Datei `widget.json`).
/// Wird von der App geschrieben und vom Widget gelesen.
struct WidgetSnapshot: Codable {
    struct Task: Codable, Identifiable, Hashable {
        var id: String
        var title: String
        var due: Date
        var hasTime: Bool
        var priority: Int
        var colorHex: String?
    }

    var generated: Date
    var weekStart: Int
    /// Offene Aufgaben mit Datum (Überfällige und die nächsten Wochen), nächster Termin bei Wiederholungen.
    var tasks: [Task]
    /// Tage (Tagesbeginn) mit offenen Aufgaben, inkl. künftiger Wiederholungen – für die Kalenderpunkte.
    var markedDays: [Date]

    static let appGroup = "group.com.lukashammer.Planer"
    static let fileName = "widget.json"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.fileURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        if let data = try? encoder.encode(self) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: - Auswertung zu einem Zeitpunkt (das Widget rechnet selbst, weil die Datei älter sein kann)

    /// Überfällige Aufgaben zuerst, dann die von heute.
    func todayAndOverdue(at now: Date) -> [Task] {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: now)
        let startTomorrow = cal.date(byAdding: .day, value: 1, to: startToday)!
        let overdue = tasks.filter { isOverdue($0, at: now) }
            .sorted { ($0.due, -$0.priority) < ($1.due, -$1.priority) }
        let today = tasks.filter { !isOverdue($0, at: now) && $0.due >= startToday && $0.due < startTomorrow }
            .sorted { a, b in
                if a.hasTime != b.hasTime { return !a.hasTime } // ganztägige zuerst
                if a.priority != b.priority { return a.priority > b.priority }
                return a.due < b.due
            }
        return overdue + today
    }

    /// Die Aufgabe, die als Nächstes dran ist.
    func nextTask(at now: Date) -> Task? {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: now)
        let startTomorrow = cal.date(byAdding: .day, value: 1, to: startToday)!
        let todayTimed = tasks.filter { $0.hasTime && $0.due >= now && $0.due < startTomorrow }.sorted { $0.due < $1.due }
        if let t = todayTimed.first { return t }
        let todayAllDay = tasks.filter { !$0.hasTime && $0.due >= startToday && $0.due < startTomorrow }
            .sorted { $0.priority > $1.priority }
        if let t = todayAllDay.first { return t }
        let overdue = tasks.filter { isOverdue($0, at: now) }.sorted { ($0.priority, $1.due) > ($1.priority, $0.due) }
        if let t = overdue.first { return t }
        return tasks.filter { $0.due >= startTomorrow }.sorted { $0.due < $1.due }.first
    }

    func isOverdue(_ t: Task, at now: Date) -> Bool {
        t.hasTime ? t.due < now : t.due < Calendar.current.startOfDay(for: now)
    }

    /// Zeitpunkte, an denen sich die Widget-Anzeige ändert (für die Timeline).
    func changeDates(after now: Date, until end: Date) -> [Date] {
        tasks.filter { $0.hasTime && $0.due > now && $0.due < end }.map { $0.due.addingTimeInterval(60) }
    }
}
