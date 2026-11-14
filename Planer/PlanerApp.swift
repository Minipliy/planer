import SwiftUI

@main
struct PlanerApp: App {
    @State private var store = Store()
    @AppStorage("appearance") private var appearance = 0

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
                .preferredColorScheme(appearance == 1 ? .light : appearance == 2 ? .dark : nil)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        #endif
    }
}

enum AppTab: Hashable { case tasks, calendar, settings }

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var tab: AppTab = .tasks
    @State private var filter: Filter = .today
    @State private var drawerOpen = false

    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if isCompact { compact } else { regular }
        }
        .background(Theme.background)
        .task {
            Reminders.requestPermission()
            // Solange die App offen ist, regelmäßig mit dem Server abgleichen.
            while !Task.isCancelled {
                await store.sync()
                try? await Task.sleep(for: .seconds(15))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.scheduleSync() }
            if phase == .background { WidgetExport.update(store: store) }
        }
        #if DEBUG
        .onAppear {
            // Nur für App-Store-Screenshots: -debugStartTab calendar|settings, -debugFilter week
            switch UserDefaults.standard.string(forKey: "debugStartTab") {
            case "calendar": tab = .calendar
            case "settings": tab = .settings
            default: break
            }
            if UserDefaults.standard.string(forKey: "debugFilter") == "week" { filter = .week }
            #if os(macOS)
            DebugShot.runIfRequested()
            #endif
        }
        #endif
    }

    // iPhone: schwebende Tab-Leiste unten, Listen als Seitenmenü.
    private var compact: some View {
        ZStack(alignment: .bottom) {
            content(showsMenu: true)
                .environment(\.bottomBarInset, 76)
            FloatingTabBar(tab: $tab)
                .padding(.bottom, 2)
        }
        .overlay {
            ZStack(alignment: .leading) {
                if drawerOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { drawerOpen = false }
                        .transition(.opacity)
                    ListsSidebar(selection: $filter) { drawerOpen = false }
                        .frame(width: 310)
                        .background(Theme.background.ignoresSafeArea())
                        .transition(.move(edge: .leading))
                }
            }
            .animation(.snappy(duration: 0.28), value: drawerOpen)
        }
    }

    // iPad / Mac: Symbolleiste links, Listen dauerhaft sichtbar.
    private var regular: some View {
        HStack(spacing: 0) {
            IconRail(tab: $tab)
            Divider()
            if tab == .tasks {
                ListsSidebar(selection: $filter, onSelect: nil)
                    .frame(width: 270)
                Divider()
            }
            content(showsMenu: false)
                .environment(\.bottomBarInset, 0)
        }
    }

    @ViewBuilder
    private func content(showsMenu: Bool) -> some View {
        switch tab {
        case .tasks:
            TaskListScreen(filter: filter, onMenu: showsMenu ? { drawerOpen = true } : nil)
                .id(filter)
        case .calendar:
            CalendarScreen()
        case .settings:
            SettingsScreen()
        }
    }
}

struct FloatingTabBar: View {
    @Binding var tab: AppTab

    var body: some View {
        HStack(spacing: 4) {
            item(.tasks) {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(tab == .tasks ? Theme.accent : Color.primary.opacity(0.85))
            }
            item(.calendar) { CalendarDayIcon(selected: tab == .calendar) }
            item(.settings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(tab == .settings ? Theme.accent : Color.primary.opacity(0.85))
            }
        }
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }

    private func item<Icon: View>(_ value: AppTab, @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            tab = value
        } label: {
            icon()
                .frame(width: 84, height: 48)
                .background(tab == value ? Color.primary.opacity(0.08) : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct IconRail: View {
    @Binding var tab: AppTab

    var body: some View {
        VStack(spacing: 14) {
            rail(.tasks, "Aufgaben") {
                Image(systemName: "checkmark.square.fill").font(.system(size: 24))
                    .foregroundStyle(tab == .tasks ? Theme.accent : Color.secondary)
            }
            rail(.calendar, "Kalender") { CalendarDayIcon(selected: tab == .calendar) }
            Spacer()
            rail(.settings, "Einstellungen") {
                Image(systemName: "gearshape.fill").font(.system(size: 22))
                    .foregroundStyle(tab == .settings ? Theme.accent : Color.secondary)
            }
        }
        .padding(.vertical, 18)
        .frame(width: 64)
    }

    private func rail<Icon: View>(_ value: AppTab, _ label: String, @ViewBuilder icon: () -> Icon) -> some View {
        Button { tab = value } label: {
            icon()
                .frame(width: 46, height: 46)
                .background(tab == value ? Color.primary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Smarte Listen und eigene Listen.
struct ListsSidebar: View {
    @Binding var selection: Filter
    var onSelect: (() -> Void)?
    @Environment(Store.self) private var store
    @State private var editingList: TaskList?

    var body: some View {
        // Ohne Scrollbereich, solange alles passt (zeichnet auf dem Mac sauberer).
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) { content; Spacer(minLength: 0) }
            ScrollView { content }
        }
        .sheet(item: $editingList) { ListEditView(list: $0) }
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text("Planer")
                    .font(.title2.bold())
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                row(.today, "Heute", "sun.max.fill", .orange)
                row(.tomorrow, "Morgen", "sunrise.fill", .yellow)
                row(.week, "Nächste 7 Tage", "calendar.badge.clock", .purple)
                row(.inbox, "Eingang", "tray.fill", Theme.accent)
                row(.all, "Alle", "square.stack.fill", .teal)
                row(.completed, "Erledigt", "checkmark.square.fill", .green)

                HStack {
                    Text("Listen").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button { editingList = TaskList(name: "") } label: {
                        Image(systemName: "plus").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Neue Liste")
                }
                .padding(.horizontal, 14)
                .padding(.top, 22)
                .padding(.bottom, 6)

                ForEach(store.visibleLists) { list in
                    row(.list(list.id), list.name, "list.bullet", list.color)
                        .contextMenu {
                            Button("Bearbeiten", systemImage: "pencil") { editingList = list }
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                if selection == .list(list.id) { selection = .inbox }
                                store.delete(list)
                            }
                        }
                }
                if store.visibleLists.isEmpty {
                    Button { editingList = TaskList(name: "") } label: {
                        Label("Neue Liste", systemImage: "plus")
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                }
                SyncBadge()
                    .padding(.horizontal, 14)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
    }

    private func row(_ filter: Filter, _ title: String, _ icon: String, _ color: Color) -> some View {
        let count = filter == .completed ? 0 : store.openCount(for: filter)
        return Button {
            selection = filter
            onSelect?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title).foregroundStyle(.primary)
                Spacer()
                if count > 0 {
                    Text("\(count)").foregroundStyle(.secondary).font(.subheadline)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(selection == filter ? Theme.card : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SyncBadge: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 6) {
            switch store.syncStatus {
            case .notConfigured:
                Image(systemName: "icloud.slash")
                Text("Kein Server eingerichtet")
            case .idle, .syncing:
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Synchronisiere …")
            case .ok:
                Image(systemName: "checkmark.icloud")
                Text("Synchronisiert")
            case .error(let message):
                Image(systemName: "exclamationmark.icloud").foregroundStyle(.orange)
                Text(message)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

#if DEBUG && os(macOS)
import AppKit

/// Nur in Debug-Builds: speichert das eigene Fenster (1440×900 pt) als PNG für App-Store-Screenshots.
/// Aufruf: Planer -debugShotName heute.png → Datei im temporären Ordner des App-Containers.
enum DebugShot {
    static func runIfRequested() {
        guard let name = UserDefaults.standard.string(forKey: "debugShotName") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }) else { return }
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                guard let view = window.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
                exit(0)
            }
        }
    }
}
#endif
