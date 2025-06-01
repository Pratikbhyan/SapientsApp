import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    private let imageUrl = URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuD_Q9AxAcKCUO5VUbkNYJLiOM7ZHmuCFjg9ZpBxMQLSE-nOgq6AtNWiKZlLMdt1vY4P4JHtLduSrwREWQG8AO8oR4_dAE5ND3_IHx5SVFYZIAu6nt-SLQIKfeL1dJKykKqH2BJ6o1suGkvC9FS76hSOrlusdBb-GAAJ7WhuKzwbAIU0H4KNqDhyXHEMvUpVxbteMCCUkdWFlbRs3uBF-wovB3x8WADhUDRo_KRGTZQt9UOaPrBoRsxEfE1eaoB7tB4QOZ78I9Te9X8")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44) // Ensure tappable area
                }
                Spacer()
                Text("Upgrade")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                // Invisible placeholder to balance the X button for centering title
                Rectangle().fill(Color.clear).frame(width: 44, height: 44)
            }
            .padding(.horizontal)
            .padding(.top, 10) // Adjust top padding as needed for sheet presentation
            .padding(.bottom, 10)
            .background(.regularMaterial)
            .overlay(Divider(), alignment: .bottom)

            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Text("Unlock premium features and exclusive content.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top)

                    // Unlock Premium Card
                    VStack(spacing: 0) {
                        CachedAsyncImage(url: imageUrl) {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .aspectRatio(1.6, contentMode: .fill)
                                .background(Color.gray.opacity(0.1))
                        }
                        .aspectRatio(1.6, contentMode: .fill) // Apply to CachedAsyncImage directly
                        .frame(height: 200) // Adjust height as needed, or use aspectRatio to define height based on width
                        .clipped()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unlock Premium")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Access all premium features and content.")
                                .font(.body)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Monthly Plan Selection Box
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monthly")
                            .font(.title2)
                            .fontWeight(.bold)
                        HStack(alignment: .firstTextBaseline) {
                            Text("$3.99")
                                .font(.system(size: 40, weight: .black))
                            Text("/month")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "#87CEEB")) // Sky Blue
                            Text("Billed monthly")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#87CEEB"), lineWidth: 2) // Sky Blue border
                    )
                    .padding(.horizontal)

                    // Premium Features List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Premium Features:")
                            .font(.headline)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(text: "Unlimited access to all content")
                            FeatureRow(text: "Download content for offline access")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    Text("Your subscription will auto-renew monthly until you cancel.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 30) // Increased top padding for separation

                    Spacer()
                }
            }

            // Fixed Footer Button
            VStack(spacing:0) {
                Divider()
                Button(action: {
                    // TODO: Handle subscription action
                    print("Subscribe tapped in modal")
                }) {
                    Text("Subscribe")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#87CEEB")) // Sky Blue
                        .cornerRadius(25) // Pill shape
                }
                .padding(.horizontal)
                .padding(.vertical, 10) // Add some vertical padding for the button itself
            }
            .background(.thinMaterial) // To give a slight blur effect for the footer
        }
    }
}

// Helper to use hex colors
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

struct FeatureRow: View {
    let text: String

    var body: some View {
        HStack {
            Image(systemName: "checkmark") // Using a standard checkmark, as list-disc is HTML specific
                .foregroundColor(Color(hex: "#87CEEB")) // Sky Blue
            Text(text)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
}
