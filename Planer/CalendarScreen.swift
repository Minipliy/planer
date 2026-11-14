import SwiftUI

struct CalendarScreen: View {
    @Environment(Store.self) private var store
    @Environment(\.bottomBarInset) private var bottomInset
    @AppStorage("weekStart") private var weekStart = 2
    @AppStorage("showCompleted") private var showCompleted = true
    @State private var month = CalendarScreen.startOfMonth(Date())
    @State private var selected = Date().startOfDay
    @State private var weekOnly = false
    @State private var editing: TaskItem?
    @State private var quickAdd = false

    private static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: date))!
    }

    var body: some View {
        let byDay = store.tasksByDay()
        let dayTasks = byDay[selected] ?? []
        let open = dayTasks.filter { !$0.isCompleted }
        let done = dayTasks.filter(\.isCompleted)

        VStack(spacing: 0) {
            ScreenHeader(title: nil, centerTitle: headerTitle) {
                Button { withAnimation(.snappy) { weekOnly.toggle() } } label: {
                    CircleIcon(systemName: weekOnly ? "calendar" : "rectangle.split.1x2")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekOnly ? "Monatsansicht" : "Wochenansicht")
            } trailing: {
                PillGroup {
                    Button {
                        withAnimation {
                            month = Self.startOfMonth(Date())
                            selected = Date().startOfDay
                        }
                    } label: { PillIcon(systemName: "calendar.badge.clock") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Heute")
                    Menu {
                        Toggle("Erledigte anzeigen", systemImage: "checkmark.square", isOn: $showCompleted)
                        Picker("Woche beginnt am", selection: $weekStart) {
                            Text("Montag").tag(2)
                            Text("Sonntag").tag(1)
                        }
                    } label: { PillIcon(systemName: "ellipsis") }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                }
            }

            MonthGrid(month: month, selected: selected, markers: byDay, weekOnly: weekOnly) { day in
                selected = day
                if !weekOnly && !Calendar.current.isDate(day, equalTo: month, toGranularity: .month) {
                    withAnimation { month = Self.startOfMonth(day) }
                }
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    shift(value.translation.width < 0 ? 1 : -1)
                }
            )

            List {
                Section {
                    Text(dayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if open.isEmpty {
                        Text("Keine Aufgaben").foregroundStyle(.tertiary)
                    }
                    ForEach(open) { task in
                        TaskRow(task: task, compact: true) { editing = task }
                    }
                }
                .listRowBackground(Theme.card)
                if showCompleted && !done.isEmpty {
                    Section {
                        Text("Erledigt")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(done) { task in
                            TaskRow(task: task, compact: true) { editing = task }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                Color.clear.frame(height: bottomInset + 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .modifier(CardListStyle())
            .refreshable { await store.sync() }
        }
        .background(Theme.background)
        .overlay(alignment: .bottomTrailing) {
            AddButton { quickAdd = true }
                .padding(.trailing, 22)
                .padding(.bottom, bottomInset + 18)
        }
        .sheet(item: $editing) { TaskDetailSheet(task: $0) }
        .sheet(isPresented: $quickAdd) {
            QuickAddSheet(template: store.newTask(filter: nil, day: selected))
        }
    }

    private var headerTitle: String {
        let sameYear = Calendar.current.isDate(month, equalTo: Date(), toGranularity: .year)
        let ref = weekOnly ? selected : month
        return sameYear
            ? ref.formatted(.dateTime.month(.wide).locale(german))
            : ref.formatted(.dateTime.month(.wide).year().locale(german))
    }

    private var dayTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(selected) { return "Heute" }
        if cal.isDateInTomorrow(selected) { return "Morgen" }
        if cal.isDateInYesterday(selected) { return "Gestern" }
        return selected.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(german))
    }

    private func shift(_ delta: Int) {
        let cal = Calendar.current
        withAnimation(.snappy) {
            if weekOnly {
                selected = cal.date(byAdding: .day, value: 7 * delta, to: selected)!
                month = Self.startOfMonth(selected)
            } else {
                month = cal.date(byAdding: .month, value: delta, to: month)!
                let today = Date().startOfDay
                selected = Self.startOfMonth(today) == month ? today : month
            }
        }
    }
}
