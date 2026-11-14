import Foundation
import UserNotifications

/// Lokale Erinnerungen. Jedes Gerät plant sie selbst aus den synchronisierten Aufgaben.
enum Reminders {
    private final class Delegate: NSObject, UNUserNotificationCenterDelegate {
        func userNotificationCenter(_ center: UNUserNotificationCenter,
                                    willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
            [.banner, .sound, .list]
        }
    }
    private static let delegate = Delegate()

    static func setup() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func reschedule(_ tasks: [TaskItem]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = Date()
        var upcoming: [(TaskItem, Date, Int)] = []
        for t in tasks where !t.deleted && !t.isCompleted {
            for (i, fire) in t.reminderDates.enumerated() where fire > now { upcoming.append((t, fire, i)) }
        }
        upcoming.sort { $0.1 < $1.1 }
        for (task, fire, index) in upcoming.prefix(60) { // iOS erlaubt maximal 64 geplante Mitteilungen
            let content = UNMutableNotificationContent()
            content.title = task.title
            if let label = task.dueLabel { content.body = label }
            content.sound = .default
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: "\(task.id)-\(index)", content: content, trigger: trigger))
        }
    }
}
