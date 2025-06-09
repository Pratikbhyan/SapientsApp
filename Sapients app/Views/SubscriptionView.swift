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
                // Monthly subscription card as button
                if let monthlyProduct = storeKit.monthlyProduct {
                    Button(action: {
                        Task {
                            await handlePurchase()
                        }
                    }) {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Subscribe Monthly")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if storeKit.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                    .padding(.top, 8)
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.53, green: 0.81, blue: 0.92), lineWidth: 2)
                        )
                    }
                    .disabled(storeKit.isLoading)
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(storeKit.isLoading ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: storeKit.isLoading)
                } else if storeKit.isLoading {
                    // Loading state
                    VStack(alignment: .center, spacing: 8) {
                        Text("Subscribe Monthly")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    // Error state - reload button
                    Button(action: {
                        Task {
                            await storeKit.loadProducts()
                        }
                    }) {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Subscribe Monthly")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Tap to reload")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Continue button for existing subscribers
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
                    // Restore purchases button
                    Button("Restore Purchases") {
                        Task {
                            await storeKit.restorePurchases()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(Color(red: 0.53, green: 0.81, blue: 0.92))
                    .disabled(storeKit.isLoading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 20)
        }
        .task {
            await storeKit.loadProducts()
        }
    }
    
    private func handlePurchase() async {
        // Reload products if none available
        if storeKit.monthlyProduct == nil {
            await storeKit.loadProducts()
        }
        
        guard let product = storeKit.monthlyProduct else {
            return
        }
        
        do {
            let result = try await storeKit.purchase(product)
            
            if result != nil {
                await MainActor.run {
                    dismiss()
                }
            }
        } catch {
            // Error handling is done in StoreKitService
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
