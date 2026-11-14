import SwiftUI

enum Theme {
    static let accent = Color(hex: "4772FA")
    #if os(iOS)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let raised = Color(uiColor: .tertiarySystemGroupedBackground)
    #else
    static let background = Color(nsColor: .windowBackgroundColor)
    static let card = Color(nsColor: .controlBackgroundColor)
    static let raised = Color(nsColor: .quaternaryLabelColor).opacity(0.5)
    #endif
}

/// Abstand, den die schwebende Tab-Leiste unten belegt.
private struct BottomBarInsetKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var bottomBarInset: CGFloat {
        get { self[BottomBarInsetKey.self] }
        set { self[BottomBarInsetKey.self] = newValue }
    }
}

struct CircleIcon: View {
    let systemName: String
    var tint: Color = .primary
    var fill: Color = Theme.card
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .contentShape(Circle())
    }
}

/// Eckiges Kontrollkästchen; Rahmenfarbe = Priorität.
struct CheckBox: View {
    let checked: Bool
    var color: Color = .secondary
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(checked ? Color.secondary.opacity(0.35) : Color.clear)
            RoundedRectangle(cornerRadius: size * 0.26)
                .strokeBorder(checked ? Color.clear : color, lineWidth: 1.8)
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle().inset(by: -10))
    }
}

/// Kalendersymbol mit dem heutigen Tag.
struct CalendarDayIcon: View {
    var selected: Bool
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Theme.accent : Color.primary.opacity(0.85))
                .frame(width: 26, height: 24)
                .padding(.top, 3)
            HStack(spacing: 10) {
                Capsule().frame(width: 3, height: 6)
                Capsule().frame(width: 3, height: 6)
            }
            .foregroundStyle(selected ? Theme.accent : Color.primary.opacity(0.85))
            Text("\(Calendar.current.component(.day, from: Date()))")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(selected ? Color.white : Theme.background)
                .padding(.top, 8)
        }
        .compositingGroup()
        .frame(width: 30, height: 30)
    }
}

struct AddButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: .command)
        .accessibilityLabel("Neue Aufgabe")
    }
}

/// Kopfzeile im Stil der Listenansicht: runde Knöpfe und großer Titel.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    var title: String?
    var centerTitle: String? = nil
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                leading
                Spacer()
                if let centerTitle {
                    Text(centerTitle).font(.title3.weight(.semibold))
                    Spacer()
                }
                trailing
            }
            .frame(minHeight: 44)
            if let title {
                Text(title).font(.largeTitle.bold()).padding(.leading, 2)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}

/// Mehrere Knöpfe in einer Kapsel (oben rechts).
struct PillGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 2) { content }
            .padding(.horizontal, 6)
            .frame(height: 44)
            .background(Theme.card, in: Capsule())
    }
}

struct PillIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
    }
}

// MARK: - Monatsraster

struct MonthGrid: View {
    let month: Date
    let selected: Date?
    var markers: [Date: [TaskItem]] = [:]
    var weekOnly = false
    var cellHeight: CGFloat = 46
    let onSelect: (Date) -> Void
    @AppStorage("weekStart") private var weekStart = 2
    @Environment(\.colorScheme) private var scheme

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStart
        return cal
    }

    private var days: [Date] {
        let cal = calendar
        let anchor = weekOnly ? (selected ?? month) : month
        let start = cal.dateInterval(of: .weekOfYear, for: anchor)!.start
        let count = weekOnly ? 7 : 42
        return (0..<count).map { cal.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Weekday.ordered(start: weekStart), id: \.self) { wd in
                Text(String(Weekday.long(wd).prefix(1)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: 26)
            }
            ForEach(days, id: \.self) { day in
                cell(day)
                    .onTapGesture { onSelect(day) }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isSelected = selected.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isToday = cal.isDateInToday(day)
        let inMonth = weekOnly || cal.isDate(day, equalTo: month, toGranularity: .month)
        let items = markers[day.startOfDay] ?? []
        let hasOpen = items.contains { !$0.isCompleted }
        return VStack(spacing: 3) {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 17, weight: isSelected || isToday ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? Color.white
                    : isToday ? Theme.accent
                    : inMonth ? Color.primary : Color.secondary.opacity(0.6)
                )
                .frame(width: 36, height: 36)
                .background {
                    if isSelected { Circle().fill(Theme.accent) }
                    else if isToday { Circle().fill(scheme == .dark ? Color.white : Theme.accent.opacity(0.12)) }
                }
            Circle()
                .fill(hasOpen ? Theme.accent : Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
                .opacity(items.isEmpty ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cellHeight)
        .contentShape(Rectangle())
    }
}

// MARK: - Schnelleingabe mit Datumserkennung

/// Erkennt in der Schnelleingabe z. B. „morgen 15 Uhr #arbeit !hoch“.
enum QuickParser {
    struct Result {
        var title: String
        var date: Date?
        var hasTime = false
        var priority: Priority?
        var tags: [String] = []
    }

    static func parse(_ input: String, now: Date = Date()) -> Result {
        var text = " " + input + " "
        var result = Result(title: input)
        let cal = Calendar.current
        var day: Date?
        var time: (Int, Int)?

        func take(_ pattern: String, _ handle: ([String]) -> Void) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            let ns = text as NSString
            guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return }
            var groups: [String] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
            }
            handle(groups)
            text = ns.replacingCharacters(in: m.range, with: " ")
        }

        take(#"\s(übermorgen)\s"#) { _ in day = now.startOfDay.addingDays(2) }
        take(#"\s(heute)\s"#) { _ in day = now.startOfDay }
        take(#"\s(morgen)\s"#) { _ in day = now.startOfDay.addingDays(1) }
        let names = ["sonntag", "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag"]
        take(#"\s(?:am\s+)?(nächsten?\s+)?(sonntag|montag|dienstag|mittwoch|donnerstag|freitag|samstag)\s"#) { g in
            guard let idx = names.firstIndex(of: g[2].lowercased()) else { return }
            let today = cal.component(.weekday, from: now)
            var diff = (idx + 1 - today + 7) % 7
            if diff == 0 { diff = 7 }
            day = now.startOfDay.addingDays(diff)
        }
        take(#"\s(?:um\s+)?(\d{1,2}):(\d{2})(?:\s*uhr)?\s"#) { g in
            if let h = Int(g[1]), let m = Int(g[2]), h < 24, m < 60 { time = (h, m) }
        }
        if time == nil {
            take(#"\s(?:um\s+)?(\d{1,2})\s*uhr\s"#) { g in
                if let h = Int(g[1]), h < 24 { time = (h, 0) }
            }
        }
        take(#"\s!(hoch|3)\s"#) { _ in result.priority = .high }
        take(#"\s!(mittel|2)\s"#) { _ in result.priority = .medium }
        take(#"\s!(niedrig|1)\s"#) { _ in result.priority = .low }
        while true {
            var found = false
            take(#"\s#([\p{L}\p{N}_-]+)"#) { g in result.tags.append(g[1]); found = true }
            if !found { break }
        }

        if let time {
            let base = day ?? now.startOfDay
            result.date = cal.date(bySettingHour: time.0, minute: time.1, second: 0, of: base)
            result.hasTime = true
        } else {
            result.date = day
        }
        result.title = text.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return result
    }
}
