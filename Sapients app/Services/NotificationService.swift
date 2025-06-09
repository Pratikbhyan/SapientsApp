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
        // You'll need to modify this based on your ContentRepository logic
        let contentRepo = ContentRepository()
        
        // This is a simplified check - you might need to adjust based on your data structure
        return await contentRepo.hasContentForDate(today)
    }
    
    // MARK: - Cancel Daily Notifications
    func cancelDailyNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_episode"])
    }
}

// MARK: - ContentRepository Extension
extension ContentRepository {
    func hasContentForDate(_ date: Date) async -> Bool {
        // Implement this based on your current data fetching logic
        // This is a placeholder - you'll need to check your Supabase data
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Check if there's content for this date
            // Adjust this query based on your actual database structure
            let response: [Content] = try await SupabaseManager.shared.client
                .from("content")
                .select()
                .gte("created_at", value: dateString)
                .lt("created_at", value: dateString + "T23:59:59")
                .execute()
                .value
            
            return !response.isEmpty
        } catch {
            print("Error checking for content: \(error)")
            return false
        }
    }
}