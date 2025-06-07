import Foundation
import StoreKit
import Combine

@MainActor
class StoreKitService: NSObject, ObservableObject {
    static let shared = StoreKitService()
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Product IDs
    private let productIDs: Set<String> = [
        "com.sapients"  // This should match exactly what you created in App Store Connect
    ]
    
    // MARK: - Subscription Status
    var hasActiveSubscription: Bool {
        return !purchasedProductIDs.isEmpty
    }
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    override init() {
        super.init()
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products and check purchase status
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            self.products = storeProducts
            print("Loaded \(storeProducts.count) products")
            for product in storeProducts {
                print("Product ID: \(product.id), Display Name: \(product.displayName), Price: \(product.displayPrice)")
            }
        } catch {
            print("Failed to load products: \(error)")
            self.errorMessage = "Failed to load subscription options"
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Product
    func purchase(_ product: Product) async throws -> Transaction? {
        print("Attempting to purchase product: \(product.id)")
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            print("Purchase result: \(result)")
            
            switch result {
            case .success(let verification):
                print("Purchase successful, verifying transaction...")
                let transaction = try await checkVerified(verification)
                
                // The transaction is verified. Deliver content to the user.
                await updatePurchasedProducts()
                
                // Always finish a transaction.
                await transaction.finish()
                
                isLoading = false
                return transaction
                
            case .userCancelled:
                print("Purchase cancelled by user")
                isLoading = false
                return nil
                
            case .pending:
                print("Purchase is pending")
                isLoading = false
                return nil
                
            @unknown default:
                print("Unknown purchase result")
                isLoading = false
                return nil
            }
        } catch {
            print("Purchase failed with error: \(error)")
            self.errorMessage = "Purchase failed. Please try again."
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        try? await AppStore.sync()
        await updatePurchasedProducts()
        
        isLoading = false
    }
    
    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try await checkVerified(result)
                
                // Check if the subscription is still active
                if let subscriptionStatus = try await transaction.subscriptionStatus {
                    switch subscriptionStatus.state {
                    case .subscribed, .inGracePeriod:
                        purchasedIDs.insert(transaction.productID)
                    default:
                        break
                    }
                } else {
                    // For non-subscription products
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
        print("Updated purchased products: \(purchasedIDs)")
    }
    
    // MARK: - Listen for Transactions
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Deliver products to the user.
                    await self.updatePurchasedProducts()
                    
                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    func checkVerified<T>(_ result: VerificationResult<T>) async throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    var monthlyProduct: Product? {
        return products.first { $0.id == "com.sapients" }
    }
}

// MARK: - Store Errors
enum StoreError: Error {
    case failedVerification
}

extension StoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}
