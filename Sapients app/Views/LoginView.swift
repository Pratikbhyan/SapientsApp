import SwiftUI

struct LoginView: View {
    @Binding var isUserLoggedIn: Bool

    // Controls for logo size and position
    @State private var logoWidth: CGFloat = 400 // Adjust desired width here
    @State private var logoHeight: CGFloat = 400 // Adjust desired height here
    @State private var logoOffsetX: CGFloat = -50      // Adjust X offset (from left edge)
    @State private var logoOffsetY: CGFloat = 10 // Adjust Y offset (negative moves up)
    var body: some View {
        ZStack {
            Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                // App Icon
                Image("app_icon") // Ensure "app_icon" is in Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoWidth, height: logoHeight)
                    // Align the image's frame to the leading edge of the available space
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Apply offsets for fine-tuning position
                    .offset(x: logoOffsetX, y: logoOffsetY)
                    .padding(.bottom, 50) // Space below the logo complex
                
                Spacer()

                // Buttons Container
                VStack(spacing: 12) {
                    AuthButton(iconName: "applelogo", text: "Continue with Apple", backgroundColor: .white, textColor: .black, action: {})
                    
                    AuthButton(imageName: "google_logo", text: "Continue with Google", backgroundColor: Color(white: 0.2), textColor: .white, action: {})
                    
                    AuthButton(iconName: "envelope.fill", text: "Sign up with email", backgroundColor: Color(white: 0.2), textColor: .white, action: {})
                    
                    Button(action: {
                        // Log in action
                        isUserLoggedIn = true // Simulate successful login
                    }) {
                        Text("Log in")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .padding(.top, 12) // Extra space before Log in button

                }
                .padding(.horizontal, 24)
                .padding(.top, 30)
                .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0 > 0 ? 30 : 15) // Adjust bottom padding based on safe area
                .background(Color.black)
                .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
            }
            .edgesIgnoringSafeArea(.bottom) // Allow black container to go to the bottom edge
        }
    }
}

struct AuthButton: View {
    var iconName: String? = nil
    var imageName: String? = nil // For custom images like Google logo
    let text: String
    let backgroundColor: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                
                if let imageName = imageName {
                    Image(imageName) // Assumes imageName is the correct asset name, e.g., "google_logo"
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 20))
                }
                
                Spacer().frame(width: 8)
                Text(text)
                    .fontWeight(.medium)
                Spacer()
            }
            // .padding(.leading, 20) // Removed: Spacers will handle centering
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(12)
        }
    }
}

// Helper to selectively round corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isUserLoggedIn: .constant(false))
    }
}

// Modify AuthButton if it's used by the main LoginView for login state changes
// For this specific case, the main "Log in" button in LoginView handles it.
// If other buttons in AuthButton needed to change the global login state,
// AuthButton would also need the @Binding.
// However, the current structure has the main "Log in" button directly in LoginView's body,
// so we only need to modify that one and the LoginView struct itself.

// The AuthButton struct was defined as:
// struct AuthButton: View {
//    var iconName: String? = nil
//    var imageName: String? = nil 
//    let text: String
//    let backgroundColor: Color
//    let textColor: Color
//    let action: () -> Void
// ...
// }
// If, for example, "Continue with Apple" should also log the user in directly,
// then AuthButton would need modification and LoginView would pass the binding to it.
// For now, only the dedicated "Log in" button changes the state.

// Note: For the Google logo, you'll need to add an image named "google_logo.png" (or similar) 
// to your Xcode project's Asset Catalog (Assets.xcassets). 
// The provided HTML used a URL, but in SwiftUI, local assets are preferred for this.
// You can find a Google logo SVG/PNG online and add it to your assets.
// For Apple icon, SFSymbols "applelogo" is used.
// For email icon, SFSymbols "envelope.fill" is used.
