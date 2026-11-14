import SwiftUI

let german = Locale(identifier: "de_DE")

func nowMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

enum Priority: Int, Codable, CaseIterable, Identifiable {
    case none = 0, low, medium, high
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .none: "Keine Priorität"
        case .low: "Niedrige Priorität"
        case .medium: "Mittlere Priorität"
        case .high: "Hohe Priorität"
        }
    }
    var color: Color {
        switch self {
        case .none: .secondary
        case .low: Color(hex: "4772FA")
        case .medium: Color(hex: "F5A623")
        case .high: Color(hex: "E5484D")
        }
    }
}

// MARK: - Wiederholung

struct Recurrence: Codable, Hashable {
    enum Unit: String, Codable, CaseIterable, Identifiable {
        case day, week, month, year
        var id: String { rawValue }
        func label(_ n: Int) -> String {
            switch self {
            case .day: n == 1 ? "Tag" : "Tage"
            case .week: n == 1 ? "Woche" : "Wochen"
            case .month: n == 1 ? "Monat" : "Monate"
            case .year: n == 1 ? "Jahr" : "Jahre"
            }
        }
    }

    var unit: Unit
    var interval = 1
    /// Kalender-Wochentage (1 = Sonntag … 7 = Samstag), nur bei wöchentlich.
    var weekdays: [Int] = []
    /// Nächster Termin ab dem Erledigt-Datum statt ab dem Fälligkeitsdatum.
    var fromCompletion = false

    static let daily = Recurrence(unit: .day)
    static let monthly = Recurrence(unit: .month)
    static let yearly = Recurrence(unit: .year)
    static let workdays = Recurrence(unit: .week, weekdays: [2, 3, 4, 5, 6])
    static func weekly(on date: Date) -> Recurrence {
        Recurrence(unit: .week, weekdays: [Calendar.current.component(.weekday, from: date)])
    }

    init(unit: Unit, interval: Int = 1, weekdays: [Int] = [], fromCompletion: Bool = false) {
        self.unit = unit
        self.interval = max(1, interval)
        self.weekdays = weekdays.sorted()
        self.fromCompletion = fromCompletion
    }

    /// Unterstützt auch das ältere Format (nur ein Text wie "weekly").
    init(from decoder: Decoder) throws {
        if let legacy = try? decoder.singleValueContainer().decode(String.self) {
            switch legacy {
            case "daily": self = .daily
            case "weekdays": self = .workdays
            case "weekly": self = Recurrence(unit: .week)
            case "monthly": self = .monthly
            case "yearly": self = .yearly
            default: throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "none"))
            }
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        unit = try c.decode(Unit.self, forKey: .unit)
        interval = max(1, try c.decodeIfPresent(Int.self, forKey: .interval) ?? 1)
        weekdays = try c.decodeIfPresent([Int].self, forKey: .weekdays) ?? []
        fromCompletion = try c.decodeIfPresent(Bool.self, forKey: .fromCompletion) ?? false
    }

    private enum CodingKeys: String, CodingKey { case unit, interval, weekdays, fromCompletion }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(unit, forKey: .unit)
        try c.encode(interval, forKey: .interval)
        try c.encode(weekdays, forKey: .weekdays)
        try c.encode(fromCompletion, forKey: .fromCompletion)
    }

    /// Nächster Termin. Die Uhrzeit von `due` bleibt erhalten.
    func next(after due: Date, completedAt: Date = Date()) -> Date {
        let cal = Calendar.current
        var base = due
        if fromCompletion {
            let time = cal.dateComponents([.hour, .minute], from: due)
            base = cal.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: completedAt) ?? completedAt
        }
        switch unit {
        case .day: return cal.date(byAdding: .day, value: interval, to: base)!
        case .month: return cal.date(byAdding: .month, value: interval, to: base)!
        case .year: return cal.date(byAdding: .year, value: interval, to: base)!
        case .week:
            if weekdays.isEmpty { return cal.date(byAdding: .day, value: 7 * interval, to: base)! }
            let baseWeek = cal.dateInterval(of: .weekOfYear, for: base)!.start
            for offset in 1...(7 * interval + 7) {
                let d = cal.date(byAdding: .day, value: offset, to: base)!
                guard weekdays.contains(cal.component(.weekday, from: d)) else { continue }
                let week = cal.dateInterval(of: .weekOfYear, for: d)!.start
                let weeks = cal.dateComponents([.weekOfYear], from: baseWeek, to: week).weekOfYear ?? 0
                if weeks % interval == 0 { return d }
            }
            return cal.date(byAdding: .day, value: 7 * interval, to: base)!
        }
    }

    func summary(for date: Date) -> String {
        let n = interval
        var text: String
        switch unit {
        case .day:
            text = n == 1 ? "Täglich" : "Alle \(n) Tage"
        case .week:
            let days = weekdays.isEmpty ? [Calendar.current.component(.weekday, from: date)] : weekdays
            if days == [2, 3, 4, 5, 6] && n == 1 { text = "Jeden Wochentag (Mo–Fr)"; break }
            let names = days.map { Weekday.short($0) }.joined(separator: ", ")
            text = (n == 1 ? "Jede Woche am " : "Alle \(n) Wochen am ") + names
        case .month:
            let day = Calendar.current.component(.day, from: date)
            text = (n == 1 ? "Monatlich" : "Alle \(n) Monate") + " am \(day)."
        case .year:
            text = (n == 1 ? "Jährlich" : "Alle \(n) Jahre") + " am " + date.formatted(.dateTime.day().month(.abbreviated).locale(german))
        }
        if fromCompletion { text += " (nach Erledigung)" }
        return text
    }
}

enum Weekday {
    /// 1 = So … 7 = Sa
    static func short(_ weekday: Int) -> String {
        ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][(weekday - 1) % 7]
    }
    static func long(_ weekday: Int) -> String {
        ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"][(weekday - 1) % 7]
    }
    /// Wochentage in Anzeige-Reihenfolge je nach Wochenbeginn (1 = So, 2 = Mo).
    static func ordered(start: Int) -> [Int] {
        (0..<7).map { (start - 1 + $0) % 7 + 1 }
    }
}

// MARK: - Aufgaben

struct Subtask: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var done = false

    init(title: String, done: Bool = false) {
        self.title = title
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
    }
}

struct TaskItem: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var notes = ""
    var listID: String? = nil
    /// Beginn bzw. Fälligkeit. Ganztägig (hasTime == false): Tagesbeginn.
    var dueDate: Date? = nil
    /// Ende bei Terminen mit Dauer.
    var endDate: Date? = nil
    var hasTime = false
    /// Erinnerungen in Minuten vor dem Termin. Ganztägig: bezogen auf 9:00 Uhr des Tages.
    var reminders: [Int] = []
    var recurrence: Recurrence? = nil
    var priority: Priority = .none
    var tags: [String] = []
    var isCompleted = false
    var completedAt: Date? = nil
    var subtasks: [Subtask] = []
    var createdAt = Date()
    var updatedAt: Int64 = nowMillis()
    var deleted = false
    /// Lokal geändert, aber noch nicht auf dem Server.
    var dirty = true

    init(title: String) { self.title = title }

    private enum CodingKeys: String, CodingKey {
        case id, title, notes, listID, dueDate, endDate, hasTime, reminders, recurrence, priority, tags
        case isCompleted, completedAt, subtasks, createdAt, updatedAt, deleted, dirty
        case reminderMinutes, repeatRule // ältere Felder
    }

    /// Fehlertolerant, damit ältere oder neuere App-Versionen dieselben Daten lesen können.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        listID = try c.decodeIfPresent(String.self, forKey: .listID)
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        endDate = try c.decodeIfPresent(Date.self, forKey: .endDate)
        hasTime = try c.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
        if let list = try c.decodeIfPresent([Int].self, forKey: .reminders) {
            reminders = list
        } else if let single = try c.decodeIfPresent(Int.self, forKey: .reminderMinutes) {
            reminders = [single]
        }
        recurrence = (try? c.decodeIfPresent(Recurrence.self, forKey: .recurrence))
            ?? (try? c.decodeIfPresent(Recurrence.self, forKey: .repeatRule)) ?? nil
        priority = (try? c.decodeIfPresent(Priority.self, forKey: .priority)) ?? .none
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        subtasks = try c.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        dirty = try c.decodeIfPresent(Bool.self, forKey: .dirty) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(listID, forKey: .listID)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
        try c.encode(hasTime, forKey: .hasTime)
        try c.encode(reminders, forKey: .reminders)
        try c.encodeIfPresent(recurrence, forKey: .recurrence)
        try c.encode(priority, forKey: .priority)
        try c.encode(tags, forKey: .tags)
        try c.encode(isCompleted, forKey: .isCompleted)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(subtasks, forKey: .subtasks)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(deleted, forKey: .deleted)
        try c.encode(dirty, forKey: .dirty)
    }

    var isOverdue: Bool {
        guard !isCompleted, let due = dueDate else { return false }
        return hasTime ? due < Date() : due < Date().startOfDay
    }

    var reminderDates: [Date] {
        guard let due = dueDate else { return [] }
        let base = hasTime ? due : due.startOfDay.addingTimeInterval(9 * 3600)
        return reminders.map { base.addingTimeInterval(TimeInterval(-$0 * 60)) }
    }

    /// z. B. "Heute", "Morgen, 14:30", "Fr., 14. Nov."
    var dueLabel: String? {
        guard let due = dueDate else { return nil }
        var text = DateText.day(due)
        if hasTime {
            text += ", " + DateText.time(due)
            if let end = endDate { text += "–" + DateText.time(end) }
        } else if let end = endDate, !Calendar.current.isDate(end, inSameDayAs: due) {
            text += " – " + DateText.day(end)
        }
        return text
    }
}

enum DateText {
    static func day(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Heute" }
        if cal.isDateInTomorrow(date) { return "Morgen" }
        if cal.isDateInYesterday(date) { return "Gestern" }
        if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(german))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(german))
    }
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(german))
    }
    static func long(_ date: Date) -> String {
        let cal = Calendar.current
        let d = date.formatted(.dateTime.day().month(.abbreviated).locale(german))
        if cal.isDateInToday(date) { return "Heute, " + d }
        if cal.isDateInTomorrow(date) { return "Morgen, " + d }
        return date.formatted(.dateTime.weekday(.abbreviated).locale(german)) + ", " + d
    }
}

struct TaskList: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var colorHex = TaskList.palette[0]
    var createdAt = Date()
    var updatedAt: Int64 = nowMillis()
    var deleted = false
    var dirty = true

    init(name: String) { self.name = name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? TaskList.palette[0]
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        dirty = try c.decodeIfPresent(Bool.self, forKey: .dirty) ?? false
    }

    var color: Color { Color(hex: colorHex) }

    static let palette = ["4772FA", "E5484D", "F5A623", "30A46C", "8E4EC6", "12A594", "E93D82", "6F6E77"]
}

enum Filter: Hashable {
    case today, tomorrow, week, inbox, all, completed
    case list(String)
}

struct TaskSection: Identifiable {
    var title: String
    var tasks: [TaskItem]
    var isCompletedSection = false
    var id: String { title }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    func addingDays(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: self)! }
}

extension Color {
    init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
