import SwiftUI

/// Datum, Uhrzeit/Dauer, Erinnerungen und Wiederholung einer Aufgabe festlegen.
struct DateSheet: View {
    @Binding var task: TaskItem
    @Environment(\.dismiss) private var dismiss

    enum Mode: Hashable { case date, duration }

    @State private var mode: Mode
    @State private var day: Date
    @State private var time: Date?
    @State private var start: Date
    @State private var end: Date
    @State private var reminders: [Int]
    @State private var recurrence: Recurrence?
    @State private var month: Date
    @State private var showTime = false
    @State private var showCustomRepeat = false
    @State private var showCustomReminder = false

    init(task: Binding<TaskItem>) {
        _task = task
        let t = task.wrappedValue
        let due = t.dueDate ?? Date()
        let cal = Calendar.current
        let defaultStart = cal.date(bySettingHour: max(8, min(cal.component(.hour, from: Date()) + 1, 20)),
                                    minute: 0, second: 0, of: due) ?? due
        _mode = State(initialValue: t.endDate != nil && t.hasTime ? .duration : .date)
        _day = State(initialValue: due.startOfDay)
        _time = State(initialValue: t.hasTime ? due : nil)
        _start = State(initialValue: t.hasTime ? due : defaultStart)
        _end = State(initialValue: t.endDate ?? (t.hasTime ? due : defaultStart).addingTimeInterval(3600))
        _reminders = State(initialValue: t.dueDate == nil ? [] : t.reminders)
        _recurrence = State(initialValue: t.recurrence)
        _month = State(initialValue: cal.date(from: cal.dateComponents([.year, .month], from: due))!)
    }

    private var hasTime: Bool { mode == .duration || time != nil }
    private var referenceDate: Date { mode == .duration ? start : day }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(systemName: "xmark", fill: Theme.raised) }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Picker("", selection: $mode) {
                        Text("Datum").tag(Mode.date)
                        Text("Dauer").tag(Mode.duration)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 190)
                    Spacer()
                    Button(action: apply) { CircleIcon(systemName: "checkmark", tint: .white, fill: Theme.accent) }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.defaultAction)
                }

                if mode == .date {
                    VStack(spacing: 4) {
                        HStack {
                            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                            Spacer()
                            Text(month.formatted(.dateTime.month(.wide).year().locale(german)))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                        MonthGrid(month: month, selected: day, cellHeight: 44) { picked in
                            day = picked
                            if !Calendar.current.isDate(picked, equalTo: month, toGranularity: .month) {
                                withAnimation { month = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: picked))! }
                            }
                        }
                        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                            if abs(v.translation.width) > abs(v.translation.height) { shiftMonth(v.translation.width < 0 ? 1 : -1) }
                        })
                    }
                } else {
                    VStack(spacing: 0) {
                        DatePicker("Beginn", selection: $start)
                            .padding(.horizontal, 16).frame(minHeight: 52)
                        Divider().padding(.leading, 16)
                        DatePicker("Ende", selection: $end, in: start...)
                            .padding(.horizontal, 16).frame(minHeight: 52)
                    }
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
                    .onChange(of: start) { old, new in end = end.addingTimeInterval(new.timeIntervalSince(old)) }
                }

                VStack(spacing: 0) {
                    if mode == .date {
                        timeRow
                        Divider().padding(.leading, 52)
                    }
                    reminderRow
                    Divider().padding(.leading, 52)
                    repeatRow
                }
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))

                Button("Zurücksetzen", role: .destructive) {
                    task.dueDate = nil
                    task.endDate = nil
                    task.hasTime = false
                    task.reminders = []
                    task.recurrence = nil
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .padding(.top, 12)
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.card)
        #if os(macOS)
        .frame(width: 460, height: 720)
        #endif
        .sheet(isPresented: $showCustomRepeat) {
            CustomRepeatSheet(rule: recurrence ?? .weekly(on: referenceDate), date: referenceDate) { recurrence = $0 }
        }
        .sheet(isPresented: $showCustomReminder) {
            CustomReminderSheet(allDay: !hasTime) { value in
                if !reminders.contains(value) { reminders.append(value) }
            }
        }
    }

    // MARK: Zeilen

    private var timeRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock").frame(width: 24)
            Text("Uhrzeit")
            Spacer()
            if let time {
                Button { showTime = true } label: { Text(DateText.time(time)) }
                    .buttonStyle(.plain)
                Button {
                    self.time = nil
                    reminders = []
                } label: { Image(systemName: "xmark").font(.footnote.weight(.semibold)) }
                .buttonStyle(.plain)
            } else {
                Button { showTime = true } label: { valueLabel("Nichts") }
                    .buttonStyle(.plain)
            }
        }
        .foregroundStyle(time == nil ? Color.primary : Theme.accent)
        .rowStyle()
        .contentShape(Rectangle())
        .onTapGesture { showTime = true }
        .popover(isPresented: $showTime, arrowEdge: .bottom) {
            TimeWheel(time: Binding(
                get: { time ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)! },
                set: { new in
                    if time == nil && reminders.isEmpty { reminders = [0] }
                    time = new
                }))
                .presentationCompactAdaptation(.popover)
        }
    }

    private var reminderRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "alarm").frame(width: 24)
            Text("Erinnerung").lineLimit(1)
            Spacer(minLength: 8)
            Menu {
                Button { reminders = [] } label: { check("Nichts", reminders.isEmpty) }
                ForEach(reminderOptions, id: \.self) { value in
                    Button {
                        if let i = reminders.firstIndex(of: value) { reminders.remove(at: i) } else { reminders.append(value) }
                    } label: {
                        check(ReminderText.label(value, allDay: !hasTime), reminders.contains(value))
                    }
                }
                Divider()
                Button("Benutzerdefiniert …", systemImage: "chevron.right") { showCustomReminder = true }
            } label: {
                if reminders.isEmpty {
                    valueLabel("Nichts")
                } else {
                    Text(reminders.sorted().map { ReminderText.label($0, allDay: !hasTime) }.joined(separator: ", "))
                        .lineLimit(1)
                        .foregroundStyle(Theme.accent)
                }
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            if !reminders.isEmpty {
                Button { reminders = [] } label: { Image(systemName: "xmark").font(.footnote.weight(.semibold)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
        }
        .foregroundStyle(reminders.isEmpty ? Color.primary : Theme.accent)
        .rowStyle()
    }

    private var repeatRow: some View {
        let d = referenceDate
        let cal = Calendar.current
        return HStack(spacing: 14) {
            Image(systemName: "repeat").frame(width: 24)
            Text("Wiederholung")
            Spacer(minLength: 8)
            Menu {
                Button { recurrence = nil } label: { check("Nichts", recurrence == nil) }
                Button { recurrence = .daily } label: { check("Täglich", recurrence == .daily) }
                Button { recurrence = .weekly(on: d) } label: {
                    check("Wöchentlich (\(Weekday.long(cal.component(.weekday, from: d))))", recurrence == .weekly(on: d))
                }
                Button { recurrence = .monthly } label: {
                    check("Monatlich (am \(cal.component(.day, from: d)). Tag)", recurrence == .monthly)
                }
                Button { recurrence = .yearly } label: {
                    check("Jährlich (\(d.formatted(.dateTime.day().month(.abbreviated).locale(german))))", recurrence == .yearly)
                }
                Divider()
                Button { recurrence = .workdays } label: { check("Jeden Wochentag (Mo–Fr)", recurrence == .workdays) }
                Divider()
                Button("Benutzerdefiniert …", systemImage: "chevron.right") { showCustomRepeat = true }
            } label: {
                if let recurrence {
                    Text(recurrence.summary(for: d)).lineLimit(1).foregroundStyle(Theme.accent)
                } else {
                    valueLabel("Nichts")
                }
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            if recurrence != nil {
                Button { recurrence = nil } label: { Image(systemName: "xmark").font(.footnote.weight(.semibold)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
        }
        .foregroundStyle(recurrence == nil ? Color.primary : Theme.accent)
        .rowStyle()
    }

    private var reminderOptions: [Int] {
        hasTime ? [0, 5, 15, 30, 60, 1440] : [0, 1440, 2880, 4320, 10080]
    }

    private func valueLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.caption)
        }
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func check(_ title: String, _ on: Bool) -> some View {
        if on { Label(title, systemImage: "checkmark") } else { Text(title) }
    }

    private func shiftMonth(_ delta: Int) {
        withAnimation { month = Calendar.current.date(byAdding: .month, value: delta, to: month)! }
    }

    private func apply() {
        let cal = Calendar.current
        switch mode {
        case .date:
            if let time {
                let parts = cal.dateComponents([.hour, .minute], from: time)
                task.dueDate = cal.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day)
                task.hasTime = true
            } else {
                task.dueDate = day.startOfDay
                task.hasTime = false
            }
            task.endDate = nil
        case .duration:
            task.dueDate = start
            task.endDate = max(end, start)
            task.hasTime = true
        }
        task.reminders = reminders.sorted()
        task.recurrence = recurrence
        dismiss()
    }
}

private extension View {
    func rowStyle() -> some View {
        self.padding(.horizontal, 16).frame(minHeight: 52)
    }
}

struct TimeWheel: View {
    @Binding var time: Date
    var body: some View {
        DatePicker("Uhrzeit", selection: $time, displayedComponents: .hourAndMinute)
            .labelsHidden()
            #if os(iOS)
            .datePickerStyle(.wheel)
            .frame(width: 240, height: 200)
            #else
            .datePickerStyle(.stepperField)
            .padding()
            #endif
            .environment(\.locale, german)
    }
}

enum ReminderText {
    static func label(_ minutes: Int, allDay: Bool) -> String {
        if !allDay {
            switch minutes {
            case 0: return "Zum Zeitpunkt"
            case let m where m % 1440 == 0: return m == 1440 ? "1 Tag vorher" : "\(m / 1440) Tage vorher"
            case let m where m % 60 == 0: return m == 60 ? "1 Stunde vorher" : "\(m / 60) Stunden vorher"
            default: return "\(minutes) Minuten vorher"
            }
        }
        // Ganztägig: Bezugspunkt ist 9:00 Uhr des Tages.
        let offset = 9 * 60 - minutes // Minuten ab Tagesbeginn des Fälligkeitstags
        let days = Int((-Double(offset) / 1440).rounded(.up))
        let tod = offset + days * 1440
        let clock = String(format: "%02d:%02d", tod / 60, tod % 60)
        switch days {
        case 0: return "Am selben Tag (\(clock))"
        case 1: return "1 Tag früher (\(clock))"
        case 7: return "1 Woche früher (\(clock))"
        default: return "\(days) Tage früher (\(clock))"
        }
    }
}

// MARK: - Eigene Erinnerung

struct CustomReminderSheet: View {
    let allDay: Bool
    let onAdd: (Int) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var days = 0
    @State private var hours = 0
    @State private var minutes = 10
    @State private var clock = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!

    var body: some View {
        NavigationStack {
            Form {
                if allDay {
                    Stepper("\(days) \(days == 1 ? "Tag" : "Tage") vorher", value: $days, in: 0...60)
                    DatePicker("Uhrzeit", selection: $clock, displayedComponents: .hourAndMinute)
                        .environment(\.locale, german)
                } else {
                    Stepper("\(days) \(days == 1 ? "Tag" : "Tage")", value: $days, in: 0...60)
                    Stepper("\(hours) \(hours == 1 ? "Stunde" : "Stunden")", value: $hours, in: 0...23)
                    Stepper("\(minutes) Minuten", value: $minutes, in: 0...55, step: 5)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Eigene Erinnerung")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        if allDay {
                            let parts = Calendar.current.dateComponents([.hour, .minute], from: clock)
                            let tod = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
                            onAdd(9 * 60 - tod + days * 1440)
                        } else {
                            onAdd(days * 1440 + hours * 60 + minutes)
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        #if os(macOS)
        .frame(width: 380, height: 280)
        #endif
    }
}

// MARK: - Eigene Wiederholung

struct CustomRepeatSheet: View {
    let date: Date
    let onSave: (Recurrence) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weekStart") private var weekStart = 2
    @State private var rule: Recurrence

    init(rule: Recurrence, date: Date, onSave: @escaping (Recurrence) -> Void) {
        self.date = date
        self.onSave = onSave
        var r = rule
        if r.unit == .week && r.weekdays.isEmpty { r.weekdays = [Calendar.current.component(.weekday, from: date)] }
        _rule = State(initialValue: r)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { dismiss() } label: { CircleIcon(systemName: "xmark", fill: Theme.raised) }
                        .buttonStyle(.plain)
                    Spacer()
                    Text("Eigene Wiederholung").font(.headline)
                    Spacer()
                    Button {
                        onSave(rule)
                        dismiss()
                    } label: { CircleIcon(systemName: "checkmark", tint: .white, fill: Theme.accent) }
                        .buttonStyle(.plain)
                }

                HStack {
                    Text("Wiederholungstyp")
                    Spacer()
                    Picker("", selection: $rule.fromCompletion) {
                        Text("Nach Fälligkeit").tag(false)
                        Text("Nach Erledigung").tag(true)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Häufigkeit").padding([.top, .horizontal], 16)
                    HStack(spacing: 0) {
                        Text("Alle").font(.title3.weight(.semibold)).frame(maxWidth: .infinity)
                        Picker("Intervall", selection: $rule.interval) {
                            ForEach(1...30, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .wheelStyle()
                        Picker("Einheit", selection: $rule.unit) {
                            ForEach(Recurrence.Unit.allCases) { Text($0.label(rule.interval)).tag($0) }
                        }
                        .wheelStyle()
                    }
                    .frame(height: 170)
                    .onChange(of: rule.unit) { _, unit in
                        if unit == .week && rule.weekdays.isEmpty {
                            rule.weekdays = [Calendar.current.component(.weekday, from: date)]
                        } else if unit != .week {
                            rule.weekdays = []
                        }
                    }
                }
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))

                Text(rule.summary(for: date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)

                if rule.unit == .week {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Woche")
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(Weekday.ordered(start: weekStart), id: \.self) { wd in
                                let on = rule.weekdays.contains(wd)
                                Button {
                                    if on {
                                        if rule.weekdays.count > 1 { rule.weekdays.removeAll { $0 == wd } }
                                    } else {
                                        rule.weekdays = (rule.weekdays + [wd]).sorted()
                                    }
                                } label: {
                                    Text(Weekday.short(wd))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 38)
                                        .foregroundStyle(on ? Color.white : Color.primary.opacity(0.8))
                                        .background(on ? Theme.accent : Color.primary.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.card)
        #if os(macOS)
        .frame(width: 460, height: 640)
        #endif
    }
}

private extension View {
    @ViewBuilder
    func wheelStyle() -> some View {
        #if os(iOS)
        self.pickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
        #else
        self.labelsHidden().frame(maxWidth: .infinity).padding(.horizontal, 8)
        #endif
    }
}
