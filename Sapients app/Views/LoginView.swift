import SwiftUI
import AuthenticationServices // For Sign In with Apple
import UIKit // For UIApplication, UIRectCorner, UIBezierPath

struct LoginView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject var authManager: AuthManager // Use AuthManager from environment

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0).ignoresSafeArea()

                VStack(spacing: 0) {
                    // App Icon - Full screen background
                    Image("app_icon") // Ensure "app_icon" is in Assets.xcassets
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    
                    Spacer()
                }
                
                // Overlay content on top of the image
                VStack(spacing: 0) {
                    Spacer()

                    // Buttons Container
                    VStack(spacing: 12) {

                        if let errorMessage = authViewModel.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.vertical, 5)
                        }

                        if authViewModel.isLoading {
                            ProgressView()
                                .padding(.vertical, 10)
                        } else {
                            // Sign In with Apple Button
                            AuthButton(imageName: "google_logo", text: "Continue with Google", backgroundColor: Color(white: 0.2), textColor: .white, action: {
                                Task {
                                    // AuthManager will automatically update the isAuthenticated state upon successful Supabase sign-in.
                                    _ = await authViewModel.signInWithGoogle()
                                }
                            })
                            
                            SignInWithAppleButton(
                                onRequest: { request in
                                    // This part is handled by the AuthViewModel's signInWithApple method
                                    // when it creates and performs the request.
                                    // We just need to trigger the AuthViewModel's method.
                                },
                                onCompletion: { result in
                                    // This completion is for the button's action,
                                    // The actual token handling and Supabase call is in AuthViewModel's delegate methods.
                                    // AuthManager will automatically update the isAuthenticated state upon successful Supabase sign-in.
                                    // The result of Apple Sign-In is handled within AuthViewModel and its delegate methods.
                                }
                            )
                            .signInWithAppleButtonStyle(.white) // Or .black, .whiteOutline
                            .frame(height: 50) // Standard height
                            .cornerRadius(10)
                            .onTapGesture { // Use onTapGesture to call our ViewModel method
                                authViewModel.signInWithApple()
                            }
                            .disabled(authViewModel.isLoading)
                            .padding(.bottom, 30) // Increased from 10 to 30 for more black space
                        } // End of else for isLoading
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .padding(.bottom, max(30, geometry.safeAreaInsets.bottom + 15)) // Ensure proper bottom padding
                    .background(Color.black.opacity(0.9)) // Semi-transparent background for better readability
                    .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
                }
                .edgesIgnoringSafeArea(.bottom) // Allow black container to go to the bottom edge
            }
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
        LoginView()
            .environmentObject(AuthManager.shared) // Inject AuthManager for preview
            .environmentObject(AuthViewModel()) // AuthViewModel is still used locally by LoginView
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
