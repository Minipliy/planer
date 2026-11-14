import SwiftUI

struct SettingsScreen: View {
    @Environment(Store.self) private var store
    @Environment(\.bottomBarInset) private var bottomInset
    @AppStorage("appearance") private var appearance = 0
    @AppStorage("weekStart") private var weekStart = 2
    @AppStorage("showCompleted") private var showCompleted = true
    @State private var url = ""
    @State private var token = ""

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Einstellungen") { EmptyView() } trailing: { EmptyView() }
            Form {
                Section {
                    TextField("Serveradresse", text: $url, prompt: Text("https://planer.example.org"))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif
                    SecureField("Token", text: $token, prompt: Text("Token"))
                    Button("Speichern & synchronisieren") {
                        let changed = url != store.serverURL
                        store.serverURL = url
                        store.token = token
                        if changed { store.resetSync() }
                        Task { await store.sync() }
                    }
                    LabeledContent("Status") { SyncBadge() }
                    if let last = store.lastSync {
                        LabeledContent("Zuletzt", value: last.formatted(.dateTime.hour().minute().second().locale(german)))
                    }
                } header: {
                    Text("Synchronisation")
                } footer: {
                    Text("Adresse und Token zeigt dein Server beim ersten Start an. Trage auf allen Geräten dasselbe ein. Ohne Server bleiben die Daten nur auf diesem Gerät; Änderungen werden nachgereicht, sobald der Server wieder erreichbar ist.")
                }
                .listRowBackground(Theme.card)

                Section("Darstellung") {
                    Picker("Erscheinungsbild", selection: $appearance) {
                        Text("System").tag(0)
                        Text("Hell").tag(1)
                        Text("Dunkel").tag(2)
                    }
                    Picker("Woche beginnt am", selection: $weekStart) {
                        Text("Montag").tag(2)
                        Text("Sonntag").tag(1)
                    }
                    Toggle("Erledigte anzeigen", isOn: $showCompleted)
                }
                .listRowBackground(Theme.card)

                Section("Hilfe & Rechtliches") {
                    Link("Server einrichten", destination: URL(string: "https://planer.minipliy.net/einrichtung")!)
                    Link("Support", destination: URL(string: "https://planer.minipliy.net/support")!)
                    Link("Datenschutz", destination: URL(string: "https://planer.minipliy.net/datenschutz")!)
                    Link("Impressum", destination: URL(string: "https://planer.minipliy.net/impressum")!)
                }
                .listRowBackground(Theme.card)

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                }
                .listRowBackground(Theme.card)

                Color.clear.frame(height: bottomInset)
                    .listRowBackground(Color.clear)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .background(Theme.background)
        .onAppear {
            url = store.serverURL
            token = store.token
        }
    }
}

struct ListEditView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TaskList
    private let isNew: Bool

    init(list: TaskList) {
        _draft = State(initialValue: list)
        isNew = list.name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name der Liste", text: $draft.name)
                Section("Farbe") {
                    HStack {
                        ForEach(TaskList.palette, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if draft.colorHex == hex {
                                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .onTapGesture { draft.colorHex = hex }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "Neue Liste" : "Liste bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.upsert(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 260)
        #endif
    }
}
