import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Schreibt die Daten für die Widgets und lässt sie neu zeichnen.
@MainActor
enum WidgetExport {
    static func update(store: Store) {
        guard WidgetSnapshot.fileURL != nil else { return } // z. B. auf dem Mac ohne App Group
        let now = Date()
        let from = now.startOfDay.addingDays(-365)
        let until = now.startOfDay.addingDays(62)
        let tasks: [WidgetSnapshot.Task] = store.tasks.compactMap { t in
            guard !t.deleted, !t.isCompleted, let due = t.dueDate, due >= from, due < until else { return nil }
            return .init(id: t.id, title: t.title.isEmpty ? "Ohne Titel" : t.title, due: due, hasTime: t.hasTime,
                         priority: t.priority.rawValue, colorHex: store.list(t.listID)?.colorHex)
        }
        let marked = store.tasksByDay()
            .filter { $0.value.contains { !$0.isCompleted } }
            .map(\.key)
            .sorted()
        let weekStart = UserDefaults.standard.object(forKey: "weekStart") as? Int ?? 2
        WidgetSnapshot(generated: now, weekStart: weekStart, tasks: tasks, markedDays: marked).save()
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
