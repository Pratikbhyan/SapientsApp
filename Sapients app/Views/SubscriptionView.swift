import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKit = StoreKitService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Image fills top and horizontally, centered
            ZStack(alignment: .topLeading) {
                Image("unlock")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    .clipped()
                    .ignoresSafeArea(edges: .top)
                
                // Close button overlay
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 50)
            }
            
            Spacer()
            
            // Bottom subscription area
            VStack(spacing: 20) {
                // Debug info section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info:")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("Products loaded: \(storeKit.products.count)")
                        .font(.caption)
                    Text("Is loading: \(storeKit.isLoading)")
                        .font(.caption)
                    Text("Has subscription: \(storeKit.hasActiveSubscription)")
                        .font(.caption)
                    if let error = storeKit.errorMessage {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    if let product = storeKit.monthlyProduct {
                        Text("Product found: \(product.id)")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Price: \(product.displayPrice)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("No product found")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Monthly subscription card
                if let monthlyProduct = storeKit.monthlyProduct {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        HStack(alignment: .firstTextBaseline) {
                            Text(monthlyProduct.displayPrice)
                                .font(.system(size: 40, weight: .black))
                                .foregroundColor(.primary)
                            Text("/month")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.53, green: 0.81, blue: 0.92), lineWidth: 2)
                    )
                } else if storeKit.isLoading {
                    // Loading state
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        HStack(alignment: .firstTextBaseline) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                            Text("/month")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    // Error/fallback state with debug info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly Subscription")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Product ID: com.sapients")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Status: Product not loaded")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                    )
                }

                // Subscribe button
                if storeKit.hasActiveSubscription {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.53, green: 0.81, blue: 0.92))
                            .cornerRadius(25)
                    }
                } else {
                    VStack(spacing: 12) {
                        Button(action: {
                            print("=== SUBSCRIBE BUTTON TAPPED ===")
                            print("Products count: \(storeKit.products.count)")
                            print("Monthly product: \(storeKit.monthlyProduct?.id ?? "nil")")
                            print("Is loading: \(storeKit.isLoading)")
                            print("Error message: \(storeKit.errorMessage ?? "none")")
                            
                            if let product = storeKit.monthlyProduct {
                                print("Product details:")
                                print("- ID: \(product.id)")
                                print("- Type: \(product.type)")
                                print("- Display name: \(product.displayName)")
                                print("- Price: \(product.displayPrice)")
                            }
                            
                            Task {
                                await handlePurchase()
                            }
                        }) {
                            HStack {
                                if storeKit.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(storeKit.monthlyProduct != nil ? "Subscribe" : "Reload Products")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 0.53, green: 0.81, blue: 0.92))
                            .cornerRadius(25)
                        }
                        .disabled(storeKit.isLoading)
                        
                        Button("Restore Purchases") {
                            print("=== RESTORE PURCHASES TAPPED ===")
                            Task {
                                await storeKit.restorePurchases()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(Color(red: 0.53, green: 0.81, blue: 0.92))
                        .disabled(storeKit.isLoading)
                    }
                }

                // Error message and debug info
                VStack(spacing: 4) {
                    if let errorMessage = storeKit.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Debug info for sandbox testing
                    if storeKit.products.isEmpty && !storeKit.isLoading {
                        Text("Debug: No products loaded. Check App Store Connect configuration.")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .task {
            print("=== SUBSCRIPTION VIEW LOADING ===")
            await storeKit.loadProducts()
            print("=== PRODUCTS LOADED: \(storeKit.products.count) ===")
        }
    }
    
    private func handlePurchase() async {
        print("=== HANDLE PURCHASE STARTED ===")
        
        // First try to reload products if none available
        if storeKit.monthlyProduct == nil {
            print("No product available, reloading...")
            await storeKit.loadProducts()
        }
        
        guard let product = storeKit.monthlyProduct else {
            print("ERROR: Still no monthly product available after reload")
            await MainActor.run {
                storeKit.errorMessage = "Subscription not available. Please check your network connection."
            }
            return
        }
        
        print("Product found: \(product.id), attempting purchase...")
        print("Product type: \(product.type)")
        
        do {
            print("Calling storeKit.purchase...")
            let result = try await storeKit.purchase(product)
            print("Purchase completed with result: \(result != nil ? "Success" : "Failed/Cancelled")")
            
            if result != nil {
                print("Purchase successful, dismissing view")
                await MainActor.run {
                    dismiss()
                }
            } else {
                print("Purchase was cancelled or failed")
                await MainActor.run {
                    storeKit.errorMessage = "Purchase was cancelled"
                }
            }
        } catch {
            print("Purchase error: \(error)")
            print("Error type: \(type(of: error))")
            await MainActor.run {
                storeKit.errorMessage = "Purchase failed: \(error.localizedDescription)"
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
}
