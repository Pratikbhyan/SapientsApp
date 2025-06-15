import Foundation
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Setup Daily Notifications
    func setupDailyNotifications() {
        requestNotificationPermission { granted in
            if granted {
                self.scheduleSmartDailyNotifications()
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
    
    // MARK: - Schedule Smart Daily Notifications (Only When Content Available)
    private func scheduleSmartDailyNotifications() {
        // Remove any existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        Task {
            await scheduleNotificationsForUpcomingDays()
        }
    }
    
    private func scheduleNotificationsForUpcomingDays() async {
        let calendar = Calendar.current
        
        let contentRepo = await MainActor.run { ContentRepository() }
        
        // Schedule notifications for the next 30 days (you can adjust this)
        for daysAhead in 0...30 {
            guard let targetDate = calendar.date(byAdding: .day, value: daysAhead, to: Date()) else { continue }
            
            // Check if content is available for this date
            let hasContent = await contentRepo.hasContentForDate(targetDate)
            
            if hasContent {
                // Get the content to create a personalized notification
                if let content = await contentRepo.getContentForDate(targetDate) {
                    await scheduleNotificationForDate(targetDate, content: content)
                }
            }
        }
    }
    
    private func scheduleNotificationForDate(_ date: Date, content: Content) async {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // Create notification content
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "New Episode Available!"
        notificationContent.body = "📻 \(content.title) is ready to listen"
        notificationContent.sound = .default
        
        // Add custom data
        notificationContent.userInfo = [
            "type": "daily_episode",
            "content_id": content.id.uuidString,
            "date": ISO8601DateFormatter().string(from: date)
        ]
        
        // Schedule for midnight (start of day) when content becomes available
        var triggerComponents = dateComponents
        triggerComponents.hour = 0
        triggerComponents.minute = 1  // 1 minute after midnight to ensure content is available
        triggerComponents.second = 0
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents,
            repeats: false // Individual notifications, not repeating
        )
        
        // Create unique identifier for each notification
        let identifier = "daily_episode_\(content.id.uuidString)"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent,
            trigger: trigger
        )
        
        // Add the request
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Scheduled notification for \(date) - \(content.title)")
        } catch {
            print("❌ Failed to schedule notification for \(date): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Refresh Notifications (Call this periodically or when new content is added)
    func refreshNotifications() {
        print("🔄 Refreshing notifications...")
        setupDailyNotifications()
    }
    
    // MARK: - Check if new episode is available for today
    func checkForNewEpisodeNow() async -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let contentRepo = await MainActor.run { ContentRepository() }
        
        return await contentRepo.hasContentForDate(today)
    }
    
    func getTodaysEpisode() async -> Content? {
        let today = Calendar.current.startOfDay(for: Date())
        let contentRepo = await MainActor.run { ContentRepository() }
        return await contentRepo.getContentForDate(today)
    }
    
    // MARK: - Cancel All Notifications
    func cancelDailyNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All daily notifications cancelled")
    }
}
