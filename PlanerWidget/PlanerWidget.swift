import AppIntents
import SwiftUI
import WidgetKit

private let accent = Color(red: 0x47 / 255, green: 0x72 / 255, blue: 0xFA / 255)
private let german = Locale(identifier: "de_DE")

private func priorityColor(_ p: Int) -> Color {
    switch p {
    case 3: Color(red: 0.90, green: 0.28, blue: 0.30)
    case 2: Color(red: 0.96, green: 0.65, blue: 0.14)
    case 1: accent
    default: .secondary
    }
}

private func timeText(_ d: Date) -> String {
    d.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(german))
}

// MARK: - Monat blättern (interaktive Pfeile im Widget)

enum MonthOffset {
    private static let defaults = UserDefaults(suiteName: WidgetSnapshot.appGroup)
    /// Nach einer halben Stunde springt das Widget wieder auf den aktuellen Monat.
    static var value: Int {
        guard let d = defaults, let set = d.object(forKey: "widgetMonthOffsetSet") as? Date,
              Date().timeIntervalSince(set) < 1800 else { return 0 }
        return d.integer(forKey: "widgetMonthOffset")
    }
    static func shift(_ delta: Int) {
        let newValue = value + delta
        defaults?.set(newValue, forKey: "widgetMonthOffset")
        defaults?.set(Date(), forKey: "widgetMonthOffsetSet")
    }
}

struct ShiftMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "Monat wechseln"
    static var isDiscoverable = false

    @Parameter(title: "Monate") var delta: Int

    init() {}
    init(delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        MonthOffset.shift(delta)
        return .result()
    }
}

// MARK: - Timeline

struct PlanerEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let monthOffset: Int
}

struct PlanerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlanerEntry {
        PlanerEntry(date: Date(), snapshot: .preview, monthOffset: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlanerEntry) -> Void) {
        let snap = WidgetSnapshot.load() ?? (context.isPreview ? .preview : nil)
        completion(PlanerEntry(date: Date(), snapshot: snap, monthOffset: MonthOffset.value))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlanerEntry>) -> Void) {
        let now = Date()
        let snap = WidgetSnapshot.load()
        let offset = MonthOffset.value
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        var dates = [now] + (snap?.changeDates(after: now, until: tomorrow) ?? []) + [tomorrow]
        if offset != 0 { dates.append(now.addingTimeInterval(1801)) } // zurück zum aktuellen Monat
        dates = Array(Set(dates)).sorted()
        let entries = dates.map { d in
            PlanerEntry(date: d, snapshot: snap, monthOffset: d.timeIntervalSince(now) > 1800 ? 0 : offset)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Kalender-Widget (Home-Bildschirm)

struct CalendarTasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlanerCalendarTasks", provider: PlanerProvider()) { entry in
            CalendarTasksView(entry: entry)
                .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
        .configurationDisplayName("Kalender & Heute")
        .description("Monatskalender und deine Aufgaben für heute – inklusive überfälliger.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct CalendarTasksView: View {
    let entry: PlanerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MonthView(entry: entry, large: family == .systemLarge)
                .frame(maxWidth: .infinity)
            TaskColumn(entry: entry, maxCount: family == .systemLarge ? 14 : 5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct MonthView: View {
    let entry: PlanerEntry
    var large = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = entry.snapshot?.weekStart ?? 2
        return cal
    }

    private var month: Date {
        let cal = calendar
        let start = cal.date(from: cal.dateComponents([.year, .month], from: entry.date))!
        return cal.date(byAdding: .month, value: entry.monthOffset, to: start)!
    }

    /// Wochen des Monats; nil = leeres Feld vor dem 1. bzw. nach dem Monatsende.
    private var weeks: [[Date?]] {
        let cal = calendar
        let count = cal.range(of: .day, in: .month, for: month)!.count
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        cells += (0..<count).map { cal.date(byAdding: .day, value: $0, to: month)! }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private var weekdays: [Int] { (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 } }

    var body: some View {
        let marked = Set(entry.snapshot?.markedDays ?? [])
        let cellHeight: CGFloat = large ? 30 : 19
        VStack(spacing: 0) {
            HStack {
                Button(intent: ShiftMonthIntent(delta: -1)) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, height: 20)
                }
                Spacer(minLength: 0)
                Text(month.formatted(.dateTime.month(.wide).locale(german)))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button(intent: ShiftMonthIntent(delta: 1)) {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, height: 20)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.bottom, 3)

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { wd in
                    Text(["S", "M", "D", "M", "D", "F", "S"][wd - 1])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isTodayWeekday(wd) ? accent : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 2)

            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        cell(week[i], marked: marked)
                            .frame(maxWidth: .infinity)
                            .frame(height: cellHeight)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func isTodayWeekday(_ wd: Int) -> Bool {
        entry.monthOffset == 0 && calendar.component(.weekday, from: entry.date) == wd
    }

    @ViewBuilder
    private func cell(_ day: Date?, marked: Set<Date>) -> some View {
        if let day {
            let cal = calendar
            let isToday = cal.isDate(day, inSameDayAs: entry.date)
            let weekday = cal.component(.weekday, from: day)
            let weekend = weekday == 1 || weekday == 7
            let hasTasks = marked.contains(cal.startOfDay(for: day))
            ZStack {
                if isToday {
                    Circle().fill(accent).frame(width: large ? 26 : 18, height: large ? 26 : 18)
                }
                Text("\(cal.component(.day, from: day))")
                    .font(.system(size: large ? 14 : 11, weight: isToday ? .bold : .medium))
                    .foregroundStyle(isToday ? Color.white : weekend ? Color.secondary : Color.primary)
                if hasTasks && !isToday {
                    Circle().fill(accent.opacity(0.85)).frame(width: 3, height: 3)
                        .offset(y: large ? 11 : 8)
                }
            }
        } else {
            Color.clear
        }
    }
}

private struct TaskColumn: View {
    let entry: PlanerEntry
    let maxCount: Int

    var body: some View {
        let all = entry.snapshot?.todayAndOverdue(at: entry.date) ?? []
        let shown = Array(all.prefix(maxCount))
        VStack(alignment: .leading, spacing: 7) {
            if entry.snapshot == nil {
                Text("Öffne Planer einmal, damit hier deine Aufgaben erscheinen.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if shown.isEmpty {
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle").font(.title2).foregroundStyle(accent)
                Text("Nichts mehr für heute").font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            } else {
                ForEach(shown) { task in
                    let overdue = entry.snapshot?.isOverdue(task, at: entry.date) ?? false
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(task.priority == 0 ? Color.secondary : priorityColor(task.priority), lineWidth: 1.5)
                            .frame(width: 11, height: 11)
                        Text(task.title)
                            .font(.system(size: 14))
                            .foregroundStyle(overdue ? Color.red.opacity(0.9) : Color.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if task.hasTime && !overdue {
                            Text(timeText(task.due)).font(.system(size: 11)).foregroundStyle(accent)
                        }
                    }
                }
                if all.count > shown.count {
                    Text("+ \(all.count - shown.count) weitere")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Nächste Aufgabe (Sperrbildschirm)

struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlanerNextTask", provider: PlanerProvider()) { entry in
            NextTaskView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Nächste Aufgabe")
        .description("Zeigt die Aufgabe, die als Nächstes dran ist.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

struct NextTaskView: View {
    let entry: PlanerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        default: inline
        }
    }

    private func label(_ t: WidgetSnapshot.Task) -> String {
        let cal = Calendar.current
        if entry.snapshot?.isOverdue(t, at: entry.date) == true { return "überfällig" }
        if !cal.isDate(t.due, inSameDayAs: entry.date) {
            let day = t.due.formatted(.dateTime.weekday(.abbreviated).locale(german))
            return t.hasTime ? "\(day) \(timeText(t.due))" : day
        }
        return t.hasTime ? timeText(t.due) : "ganztägig"
    }

    private var inline: some View {
        Group {
            if let t = entry.snapshot?.nextTask(at: entry.date) {
                Label {
                    Text("\(label(t)) \(t.title)")
                } icon: {
                    Image(systemName: "list.bullet")
                }
            } else {
                Label("Keine Aufgaben", systemImage: "checkmark.circle")
            }
        }
    }

    private var rectangular: some View {
        let snap = entry.snapshot
        var list = snap?.todayAndOverdue(at: entry.date) ?? []
        if list.isEmpty, let next = snap?.nextTask(at: entry.date) { list = [next] }
        return VStack(alignment: .leading, spacing: 1) {
            if list.isEmpty {
                Text("Planer").font(.headline)
                Text("Keine Aufgaben").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(list.prefix(3)) { t in
                    HStack(spacing: 4) {
                        Text(label(t)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text(t.title).font(.caption).lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetAccentable()
    }
}

// MARK: - Bundle

@main
struct PlanerWidgets: WidgetBundle {
    var body: some Widget {
        CalendarTasksWidget()
        NextTaskWidget()
    }
}

extension WidgetSnapshot {
    /// Beispieldaten für die Widget-Galerie.
    static var preview: WidgetSnapshot {
        let today = Calendar.current.startOfDay(for: Date())
        func t(_ title: String, _ days: Int, _ hour: Int? = nil, _ prio: Int = 0) -> Task {
            var d = Calendar.current.date(byAdding: .day, value: days, to: today)!
            if let hour { d = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: d)! }
            return Task(id: UUID().uuidString, title: title, due: d, hasTime: hour != nil, priority: prio, colorHex: nil)
        }
        let tasks = [t("Rechnung bezahlen", -1, nil, 3), t("Einkaufen", 0), t("Team-Meeting", 0, 15, 2),
                     t("Laufen gehen", 0, 18, 1), t("Zahnarzt", 2, 10)]
        let marked = (0..<20).map { Calendar.current.date(byAdding: .day, value: $0 * 2 - 6, to: today)! }
        return WidgetSnapshot(generated: Date(), weekStart: 2, tasks: tasks, markedDays: marked)
    }
}
