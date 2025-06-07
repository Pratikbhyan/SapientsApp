import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKit = StoreKitService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 10)
            
            // Main content
            VStack(spacing: 20) {
                // Image that fits properly without overflow
                Image("unlock")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Spacer()
                
                // Bottom subscription area
                VStack(spacing: 20) {
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
                        // Error/fallback state
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Monthly Subscription")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Pricing unavailable")
                                .font(.headline)
                                .foregroundColor(.secondary)
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
                                        Text("Subscribe")
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
                            .disabled(storeKit.isLoading || storeKit.monthlyProduct == nil)
                            
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

                    // Error message
                    if let errorMessage = storeKit.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .task {
            await storeKit.loadProducts()
        }
    }
    
    private func handlePurchase() async {
        guard let product = storeKit.monthlyProduct else {
            return
        }
        
        do {
            let transaction = try await storeKit.purchase(product)
            if transaction != nil {
                dismiss()
            }
        } catch {
            print("Purchase failed: \(error)")
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
