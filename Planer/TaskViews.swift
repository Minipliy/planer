import SwiftUI

// MARK: - Aufgabenliste

struct TaskListScreen: View {
    let filter: Filter
    var onMenu: (() -> Void)?
    @Environment(Store.self) private var store
    @Environment(\.bottomBarInset) private var bottomInset
    @AppStorage("showCompleted") private var showCompleted = true
    @AppStorage("sortByPriority") private var sortByPriority = false
    @State private var completedExpanded = true
    @State private var showAllCompleted = false
    @State private var editing: TaskItem?
    @State private var quickAdd = false
    @State private var searching = false
    @State private var search = ""

    var body: some View {
        let sections = store.sections(for: filter, search: search, sortByPriority: sortByPriority)
            .filter { showCompleted || filter == .completed || !$0.isCompletedSection }
        VStack(spacing: 0) {
            ScreenHeader(title: store.title(for: filter)) {
                if let onMenu {
                    Button(action: onMenu) { CircleIcon(systemName: "line.3.horizontal") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Listen")
                }
            } trailing: {
                PillGroup {
                    Button { withAnimation { searching.toggle(); if !searching { search = "" } } } label: {
                        PillIcon(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suchen")
                    Menu {
                        Toggle("Erledigte anzeigen", systemImage: "checkmark.square", isOn: $showCompleted)
                        Picker("Sortieren", selection: $sortByPriority) {
                            Label("Nach Datum", systemImage: "calendar").tag(false)
                            Label("Nach Priorität", systemImage: "flag").tag(true)
                        }
                    } label: {
                        PillIcon(systemName: "ellipsis")
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                }
            }
            if searching {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Aufgaben durchsuchen", text: $search)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }

            List {
                ForEach(sections) { section in
                    Section {
                        if section.isCompletedSection {
                            completedSection(section)
                        } else {
                            if sections.filter({ !$0.isCompletedSection }).count > 1 || filter == .week {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(section.title == "Überfällig" ? Color.red : Color.secondary)
                            }
                            ForEach(section.tasks) { task in
                                TaskRow(task: task, showList: !isListFilter) { editing = task }
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                Color.clear.frame(height: bottomInset + 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .modifier(CardListStyle())
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label(search.isEmpty ? "Alles erledigt" : "Keine Treffer",
                              systemImage: search.isEmpty ? "checkmark.circle" : "magnifyingglass")
                    } description: {
                        Text(search.isEmpty ? "Tippe auf +, um eine Aufgabe hinzuzufügen." : "Versuche einen anderen Suchbegriff.")
                    }
                }
            }
            .refreshable { await store.sync() }
        }
        .background(Theme.background)
        .overlay(alignment: .bottomTrailing) {
            if filter != .completed {
                AddButton { quickAdd = true }
                    .padding(.trailing, 22)
                    .padding(.bottom, bottomInset + 18)
            }
        }
        .sheet(item: $editing) { TaskDetailSheet(task: $0) }
        .sheet(isPresented: $quickAdd) {
            QuickAddSheet(template: store.newTask(filter: filter))
        }
    }

    private var isListFilter: Bool {
        if case .list = filter { return true }
        return filter == .inbox
    }

    @ViewBuilder
    private func completedSection(_ section: TaskSection) -> some View {
        Button {
            withAnimation(.snappy) { completedExpanded.toggle() }
        } label: {
            HStack {
                Text("Erledigt").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(section.tasks.count)").foregroundStyle(.secondary).font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(completedExpanded ? 0 : -90))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if completedExpanded || filter == .completed {
            let limit = showAllCompleted || filter == .completed ? section.tasks.count : 5
            ForEach(section.tasks.prefix(limit)) { task in
                TaskRow(task: task, showList: !isListFilter) { editing = task }
            }
            if section.tasks.count > limit {
                Button("Zeige mehr") { withAnimation { showAllCompleted = true } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Karten-Look: gruppierte Liste ohne eigenen Hintergrund.
struct CardListStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(14)
            .environment(\.defaultMinListRowHeight, 40)
        #else
        content
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        #endif
    }
}

// MARK: - Zeile

struct TaskRow: View {
    let task: TaskItem
    var showList = true
    var compact = false
    let onOpen: () -> Void
    @Environment(Store.self) private var store

    var body: some View {
        HStack(alignment: compact ? .center : .top, spacing: 12) {
            Button {
                withAnimation(.snappy) { _ = store.toggle(task) }
            } label: {
                CheckBox(checked: task.isCompleted, color: task.priority == .none ? .secondary : task.priority.color)
            }
            .buttonStyle(.plain)
            .padding(.top, compact ? 0 : 2)
            .accessibilityLabel(task.isCompleted ? "Als offen markieren" : "Erledigen")

            if compact {
                Text(task.title.isEmpty ? "Ohne Titel" : task.title)
                    .lineLimit(1)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                Spacer(minLength: 8)
                Text(compactTrailing)
                    .font(.subheadline)
                    .foregroundStyle(task.isCompleted ? Color.secondary : task.isOverdue ? Color.red : Theme.accent)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title.isEmpty ? "Ohne Titel" : task.title)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    meta
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, compact ? 4 : 3)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { store.delete(task) } label: { Label("Löschen", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            Button { move(to: Date().startOfDay.addingDays(1)) } label: { Label("Morgen", systemImage: "sunrise") }
                .tint(.orange)
        }
        .contextMenu {
            Button("Heute", systemImage: "sun.max") { move(to: Date().startOfDay) }
            Button("Morgen", systemImage: "sunrise") { move(to: Date().startOfDay.addingDays(1)) }
            Button("Nächste Woche", systemImage: "calendar") { move(to: Date().startOfDay.addingDays(7)) }
            Menu("Priorität") {
                ForEach(Priority.allCases.reversed()) { p in
                    Button(p.label) { var t = task; t.priority = p; store.upsert(t) }
                }
            }
            Divider()
            Button("Löschen", systemImage: "trash", role: .destructive) { store.delete(task) }
        }
    }

    private var compactTrailing: String {
        if task.isCompleted, let done = task.completedAt { return DateText.time(done) }
        if let due = task.dueDate, task.hasTime { return DateText.time(due) }
        return task.dueDate.map(DateText.day) ?? ""
    }

    @ViewBuilder private var meta: some View {
        let doneSubtasks = task.subtasks.filter(\.done).count
        HStack(spacing: 8) {
            if let label = task.dueLabel {
                Text(label)
                    .foregroundStyle(task.isCompleted ? Color.secondary : task.isOverdue ? Color.red : Theme.accent)
            }
            if task.recurrence != nil { Image(systemName: "repeat") }
            if !task.reminders.isEmpty && task.dueDate != nil { Image(systemName: "alarm") }
            if !task.subtasks.isEmpty {
                Label("\(doneSubtasks)/\(task.subtasks.count)", systemImage: "checklist").labelStyle(CompactLabelStyle())
            }
            if !task.notes.isEmpty { Image(systemName: "text.alignleft") }
            ForEach(task.tags.prefix(2), id: \.self) { tag in
                Text("#" + tag).foregroundStyle(Theme.accent.opacity(0.8))
            }
            Spacer(minLength: 4)
            if showList {
                Text(store.listName(task.listID))
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// Verschiebt auf einen anderen Tag und behält die Uhrzeit bei.
    private func move(to day: Date) {
        var t = task
        let cal = Calendar.current
        if t.hasTime, let due = t.dueDate {
            let time = cal.dateComponents([.hour, .minute], from: due)
            let newDue = cal.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day)!
            if let end = t.endDate { t.endDate = end.addingTimeInterval(newDue.timeIntervalSince(due)) }
            t.dueDate = newDue
        } else {
            if let end = t.endDate, let due = t.dueDate { t.endDate = end.addingTimeInterval(day.timeIntervalSince(due)) }
            t.dueDate = day
        }
        store.upsert(t)
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - Schnelleingabe

struct QuickAddSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskItem
    @State private var text = ""
    @State private var showDate = false
    @FocusState private var focused: Bool
    private let template: TaskItem

    init(template: TaskItem) {
        self.template = template
        _draft = State(initialValue: template)
    }

    private var parsed: QuickParser.Result { QuickParser.parse(text) }

    /// Entwurf mit den aus dem Text erkannten Angaben.
    private var effective: TaskItem {
        var t = draft
        let p = parsed
        t.title = p.title
        if let date = p.date { t.dueDate = date; t.hasTime = p.hasTime }
        if let prio = p.priority { t.priority = prio }
        t.tags = Array(Set(t.tags + p.tags)).sorted()
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Was möchtest du tun?", text: $text, axis: .vertical)
                .font(.title3)
                .textFieldStyle(.plain)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(add)
                .lineLimit(1...4)

            HStack(spacing: 20) {
                let e = effective
                Button { showDate = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar")
                        if let label = e.dueLabel { Text(label).font(.subheadline) }
                    }
                    .foregroundStyle(e.dueDate == nil ? Color.secondary : Theme.accent)
                }
                Menu {
                    ForEach(Priority.allCases.reversed()) { p in
                        Button { draft.priority = p } label: { Label(p.label, systemImage: "flag.fill") }
                    }
                } label: {
                    Image(systemName: e.priority == .none ? "flag" : "flag.fill")
                        .foregroundStyle(e.priority == .none ? Color.secondary : e.priority.color)
                }
                .menuIndicator(.hidden)
                Menu {
                    Button("Eingang", systemImage: "tray") { draft.listID = nil }
                    ForEach(store.visibleLists) { l in
                        Button(l.name, systemImage: "list.bullet") { draft.listID = l.id }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: draft.listID == nil ? "tray" : "list.bullet")
                        Text(store.listName(draft.listID)).font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .menuIndicator(.hidden)
                Spacer()
                Button(action: add) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(parsed.title.isEmpty ? Color.secondary.opacity(0.4) : Theme.accent)
                }
                .disabled(parsed.title.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .buttonStyle(.plain)
            .font(.system(size: 19))

            Text("Tipp: „morgen 15 Uhr #arbeit !hoch“ wird automatisch erkannt.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .presentationDetents([.height(190)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.card)
        #if os(macOS)
        .frame(width: 520)
        #endif
        .onAppear { focused = true }
        .sheet(isPresented: $showDate) {
            DateSheet(task: Binding(get: { effective }, set: { new in
                draft.dueDate = new.dueDate
                draft.endDate = new.endDate
                draft.hasTime = new.hasTime
                draft.reminders = new.reminders
                draft.recurrence = new.recurrence
                text = removeDateWords(text)
            }))
        }
    }

    /// Nach manueller Datumswahl erkannte Datumswörter aus dem Text entfernen.
    private func removeDateWords(_ s: String) -> String {
        let p = QuickParser.parse(s)
        let tags = p.tags.map { "#" + $0 }.joined(separator: " ")
        return ([p.title, tags].filter { !$0.isEmpty }).joined(separator: " ")
    }

    private func add() {
        let t = effective
        guard !t.title.isEmpty else { return }
        var task = t
        task.id = UUID().uuidString
        task.createdAt = Date()
        store.upsert(task)
        text = ""
        draft = template
        focused = true
    }
}

// MARK: - Aufgabe bearbeiten

struct TaskDetailSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskItem
    @State private var showDate = false
    @State private var newSubtask = ""
    @State private var newTag = ""
    @State private var addingTag = false
    @FocusState private var focus: Field?

    enum Field: Hashable { case title, notes, subtask, tag }

    init(task: TaskItem) {
        _draft = State(initialValue: task)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Menu {
                    Button("Eingang", systemImage: "tray") { draft.listID = nil }
                    ForEach(store.visibleLists) { l in
                        Button(l.name, systemImage: "list.bullet") { draft.listID = l.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(store.listName(draft.listID))
                        Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                }
                .menuIndicator(.hidden)
                .tint(.primary)
                Spacer()
                Menu {
                    ForEach(Priority.allCases.reversed()) { p in
                        Button { draft.priority = p } label: {
                            if draft.priority == p { Label(p.label, systemImage: "checkmark") } else { Text(p.label) }
                        }
                    }
                } label: {
                    CircleIcon(systemName: "flag.fill",
                               tint: draft.priority == .none ? .secondary : draft.priority.color,
                               fill: Theme.raised)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                Menu {
                    Button("Duplizieren", systemImage: "plus.square.on.square") {
                        var copy = draft
                        copy.id = UUID().uuidString
                        copy.createdAt = Date()
                        store.upsert(copy)
                    }
                    Button("Löschen", systemImage: "trash", role: .destructive) {
                        store.delete(draft)
                        dismiss()
                    }
                } label: {
                    CircleIcon(systemName: "ellipsis", fill: Theme.raised)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack(spacing: 12) {
                Button {
                    draft = store.toggle(draft)
                } label: {
                    CheckBox(checked: draft.isCompleted,
                             color: draft.priority == .none ? .secondary : draft.priority.color, size: 22)
                }
                .buttonStyle(.plain)
                Button { showDate = true } label: {
                    Text(dateText)
                        .foregroundStyle(draft.dueDate == nil ? Color.secondary : draft.isOverdue ? Color.red : Theme.accent)
                }
                .buttonStyle(.plain)
                if draft.recurrence != nil { Image(systemName: "repeat").foregroundStyle(.secondary) }
                if !draft.reminders.isEmpty && draft.dueDate != nil { Image(systemName: "alarm").foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Was möchtest du tun?", text: $draft.title, axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .textFieldStyle(.plain)
                        .focused($focus, equals: .title)
                    TextField("Beschreibung", text: $draft.notes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .foregroundStyle(.secondary)
                        .focused($focus, equals: .notes)

                    if !draft.subtasks.isEmpty || focus == .subtask {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($draft.subtasks) { $sub in
                                HStack(spacing: 10) {
                                    Button { sub.done.toggle() } label: { CheckBox(checked: sub.done, size: 18) }
                                        .buttonStyle(.plain)
                                    TextField("Teilaufgabe", text: $sub.title)
                                        .textFieldStyle(.plain)
                                        .foregroundStyle(sub.done ? .secondary : .primary)
                                    Button { draft.subtasks.removeAll { $0.id == sub.id } } label: {
                                        Image(systemName: "xmark").font(.caption).foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            HStack(spacing: 10) {
                                Image(systemName: "plus").foregroundStyle(.secondary).frame(width: 18)
                                TextField("Teilaufgabe hinzufügen", text: $newSubtask)
                                    .textFieldStyle(.plain)
                                    .focused($focus, equals: .subtask)
                                    .onSubmit(addSubtask)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if !draft.tags.isEmpty || addingTag {
                        FlowTags(tags: draft.tags) { tag in draft.tags.removeAll { $0 == tag } }
                        if addingTag {
                            TextField("Neues Schlagwort", text: $newTag)
                                .textFieldStyle(.plain)
                                .focused($focus, equals: .tag)
                                .onSubmit(addTag)
                        }
                    }
                }
                .padding(20)
            }

            HStack(spacing: 28) {
                Button { addingTag = true; focus = .tag } label: { Image(systemName: "tag") }
                    .accessibilityLabel("Schlagwort hinzufügen")
                Button { focus = .subtask } label: { Image(systemName: "list.bullet.indent") }
                    .accessibilityLabel("Teilaufgabe hinzufügen")
                Spacer()
                #if os(macOS)
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
                #endif
            }
            .buttonStyle(.plain)
            .font(.system(size: 20))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.card)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
        .onChange(of: draft) { _, new in
            if !new.deleted { store.upsert(new) }
        }
        .onDisappear {
            addSubtask()
            addTag()
        }
        .sheet(isPresented: $showDate) { DateSheet(task: $draft) }
    }

    private var dateText: String {
        guard let due = draft.dueDate else { return "Datum festlegen" }
        var s = DateText.long(due)
        if draft.hasTime {
            s += ", " + DateText.time(due)
            if let end = draft.endDate { s += "–" + DateText.time(end) }
        }
        return s
    }

    private func addSubtask() {
        let title = newSubtask.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        draft.subtasks.append(Subtask(title: title))
        newSubtask = ""
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if !tag.isEmpty && !draft.tags.contains(tag) { draft.tags.append(tag) }
        newTag = ""
    }
}

struct FlowTags: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text("#" + tag)
                        Button { onRemove(tag) } label: { Image(systemName: "xmark").font(.caption2.bold()) }
                            .buttonStyle(.plain)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.14), in: Capsule())
                }
            }
        }
    }
}
