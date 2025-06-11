import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKit = StoreKitService.shared
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var imageHeight: CGFloat {
        isIPad ? 450 : 400
    }
    
    private var maxContentWidth: CGFloat {
        isIPad ? 600 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        isIPad ? 60 : 24
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Image("unlock")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: imageHeight)
                        .clipped()
                        .ignoresSafeArea(edges: .top)
                    
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
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, isIPad ? 60 : 50)
                }
                
                HStack {
                    if isIPad { Spacer() }
                    
                    VStack(spacing: isIPad ? 25 : 20) {
                        VStack(spacing: isIPad ? 14 : 12) {
                            Text("Unlock Full Access")
                                .font(isIPad ? .title : .title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Get unlimited access to all episodes")
                                .font(isIPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, isIPad ? 10 : 8)
                        
                        if let monthlyProduct = storeKit.monthlyProduct {
                            Button(action: {
                                Task {
                                    await handlePurchase()
                                }
                            }) {
                                VStack(alignment: .center, spacing: isIPad ? 10 : 8) {
                                    Text("Pro Plan")
                                        .font(isIPad ? .title2 : .title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text("Renews every 1 month")
                                        .font(isIPad ? .body : .subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(monthlyProduct.displayPrice)/month")
                                        .font(isIPad ? .largeTitle : .title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    if storeKit.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(isIPad ? 1.0 : 0.8)
                                            .padding(.top, 8)
                                    }
                                }
                                .padding(isIPad ? 28 : 24)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(isIPad ? 20 : 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                                        .stroke(Color(red: 0.53, green: 0.81, blue: 0.92), lineWidth: 2)
                                )
                            }
                            .disabled(storeKit.isLoading)
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(storeKit.isLoading ? 0.95 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: storeKit.isLoading)
                        } else if storeKit.isLoading {
                            VStack(alignment: .center, spacing: isIPad ? 10 : 8) {
                                Text("Pro Plan - Monthly")
                                    .font(isIPad ? .title2 : .title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Loading pricing...")
                                    .font(isIPad ? .body : .subheadline)
                                    .foregroundColor(.secondary)
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(isIPad ? 1.0 : 0.8)
                            }
                            .padding(isIPad ? 28 : 24)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(isIPad ? 20 : 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        } else {
                            Button(action: {
                                Task {
                                    await storeKit.loadProducts()
                                }
                            }) {
                                VStack(alignment: .center, spacing: isIPad ? 10 : 8) {
                                    Text("Pro Plan - Monthly")
                                        .font(isIPad ? .title2 : .title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text("Tap to reload pricing")
                                        .font(isIPad ? .body : .subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(isIPad ? 28 : 24)
                                .frame(maxWidth: .infinity)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(isIPad ? 20 : 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                                        .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        if storeKit.hasActiveSubscription {
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Continue")
                                    .font(isIPad ? .title3 : .headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(isIPad ? 18 : 16)
                                    .background(Color(red: 0.53, green: 0.81, blue: 0.92))
                                    .cornerRadius(isIPad ? 30 : 25)
                            }
                        } else {
                            Button("Restore Purchases") {
                                Task {
                                    await storeKit.restorePurchases()
                                }
                            }
                            .font(isIPad ? .body : .caption)
                            .foregroundColor(Color(red: 0.53, green: 0.81, blue: 0.92))
                            .disabled(storeKit.isLoading)
                        }
                        
                        VStack(spacing: isIPad ? 10 : 8) {
                            HStack(spacing: isIPad ? 24 : 16) {
                                Button("Terms of Use") {
                                    showingTerms = true
                                }
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(Color(red: 0.53, green: 0.81, blue: 0.92))
                                
                                Text("•")
                                    .font(isIPad ? .body : .caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Privacy Policy") {
                                    showingPrivacy = true
                                }
                                .font(isIPad ? .body : .caption)
                                .foregroundColor(Color(red: 0.53, green: 0.81, blue: 0.92))
                            }
                            
                            Text("Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.")
                                .font(isIPad ? .caption : .caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, isIPad ? 20 : 8)
                        }
                        .padding(.top, isIPad ? 10 : 8)
                    }
                    .frame(maxWidth: maxContentWidth)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, isIPad ? 40 : 40)
                    .padding(.top, isIPad ? 25 : 20)
                    
                    if isIPad { Spacer() }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .task {
            await storeKit.loadProducts()
        }
        .sheet(isPresented: $showingTerms) {
            TermsPrivacyView(
                title: "Terms of Use",
                url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
            )
        }
        .sheet(isPresented: $showingPrivacy) {
            TermsPrivacyView(
                title: "Privacy Policy",
                url: URL(string: "https://v0-new-project-xup9pufctgc.vercel.app/privacy")!
            )
        }
    }
    
    private func handlePurchase() async {
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
            .previewDevice("iPad Pro (12.9-inch) (6th generation)")
    }
}
