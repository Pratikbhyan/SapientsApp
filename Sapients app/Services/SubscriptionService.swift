import Foundation

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    private let storeKit = StoreKitService.shared
    
    private init() {}
    
    // Check if user has active subscription
    var hasActiveSubscription: Bool {
        return storeKit.hasActiveSubscription
    }
    
    // Check if a specific content item is free to access
    func isContentFree(_ content: Content, in allContent: [Content]) -> Bool {
        // Always free if user has subscription
        if hasActiveSubscription {
            return true
        }
        
        // Find the latest episode (most recent createdAt date)
        guard let latestContent = allContent.max(by: { $0.createdAt < $1.createdAt }) else {
            // If we can't determine latest, allow access (safety fallback)
            return true
        }
        
        // Content is free if it's the latest episode
        return content.id == latestContent.id
    }
    
    // Get user-friendly message for why content is locked
    func getSubscriptionMessage(for content: Content, in allContent: [Content]) -> String {
        if let latestContent = allContent.max(by: { $0.createdAt < $1.createdAt }),
           content.id != latestContent.id {
            return "This episode requires a Sapients subscription. Upgrade to access all previous episodes!"
        }
        return "Upgrade to Sapients Premium to access all content!"
    }
}
