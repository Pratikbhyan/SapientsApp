import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Setup Daily Notifications
    func setupDailyNotifications() {
        requestNotificationPermission { granted in
            if granted {
                self.scheduleDailyEpisodeNotification()
            }
        }
    }
    
    // MARK: - Request Permission
    private func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(granted)
                }
            }
        }
    }
    
    // MARK: - Schedule Daily 5 AM Notification
    private func scheduleDailyEpisodeNotification() {
        // Remove any existing daily episode notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_episode"])
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "New Episode Available!"
        content.body = "Your daily Sapients episode is ready to listen."
        content.sound = .default
        
        // Add custom data to help handle the notification when tapped
        content.userInfo = ["type": "daily_episode", "date": ISO8601DateFormatter().string(from: Date())]
        
        // Schedule for 5:00 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 5
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents, 
            repeats: true
        )
        
        // Create the request
        let request = UNNotificationRequest(
            identifier: "daily_episode",
            content: content,
            trigger: trigger
        )
        
        // Add the request
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily notification: \(error.localizedDescription)")
            } else {
                print("Daily episode notification scheduled for 5:00 AM")
            }
        }
    }
    
    // MARK: - Check if new episode is available
    func checkForNewEpisode() async -> Bool {
        // Get today's date
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if there's content for today
        let contentRepo = await ContentRepository()
        
        // Check if there's content scheduled for today
        return await contentRepo.hasContentForDate(today)
    }
    
    func getTodaysEpisode() async -> Content? {
        let today = Calendar.current.startOfDay(for: Date())
        let contentRepo = await ContentRepository()
        return await contentRepo.getContentForDate(today)
    }
    
    // MARK: - Cancel Daily Notifications
    func cancelDailyNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_episode"])
    }
}
