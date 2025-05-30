import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var notificationsEnabled = true
    @Environment(\.dismiss) var dismiss

    private var displayName: String {
        guard let email = authManager.user?.email else { return "User" }
        return String(email.split(separator: "@").first ?? "User")
    }

    private var profilePictureURL: URL? {
        guard let user = authManager.user else { return nil }
        let metadata = user.userMetadata // userMetadata is non-optional [String: AnyJSON]

        // Supabase User.userMetadata is [String: AnyJSON]. AnyJSON can be treated like 'Any'.
        // Accessing a key in `metadata` (e.g., metadata["avatar_url"]) returns an AnyJSON?
        if let avatarURLString = metadata["avatar_url"]?.stringValue {
            return URL(string: avatarURLString)
        }
        if let pictureURLString = metadata["picture"]?.stringValue {
            return URL(string: pictureURLString)
        }
        // Fallback for direct string casting if .stringValue isn't appropriate for the stored JSON structure
        if let avatarURLString = metadata["avatar_url"] as? String {
             return URL(string: avatarURLString)
        }
        if let pictureURLString = metadata["picture"] as? String {
             return URL(string: pictureURLString)
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
                // Custom Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.title2)
                            .padding(.leading)
                            .foregroundColor(.primary) // Use primary color for better adaptability
                    }

                    Spacer()

                    Text("Settings")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(
                            Capsule().fill(Color.gray.opacity(0.2))
                        )

                    Spacer()

                    // Placeholder for right-side item if needed, ensures centering of title
                    Image(systemName: "chevron.backward")
                        .font(.title2)
                        .padding(.trailing)
                        .opacity(0) // Invisible but takes up space
                }
                .padding(.top, 10) // Adjust as needed, especially if not using NavigationView's bar
                .padding(.bottom, 10)
                .background(Color.gray.opacity(0.1)) // Placeholder, fix UIKit module issue in project

                Divider()

                                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // Profile Section
                        HStack(spacing: 15) {
                            CachedAsyncImage(url: profilePictureURL) {
                                Image(systemName: "person.circle.fill") // Placeholder
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .foregroundColor(.gray)
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())

                            Text(displayName)
                                .font(.title3)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Notifications Toggle
                        HStack {
                            Text("Notifications")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $notificationsEnabled)
                                .labelsHidden()
                                .tint(.accentColor)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())

                        // Subscribe Row
                        Button(action: {
                            // TODO: Handle subscription logic
                            print("Subscribe button tapped")
                        }) {
                            HStack {
                                Text("Subscribe to Premium")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                        .buttonStyle(PlainButtonStyle())

                        // Logout Row
                        Button(action: {
                            Task {
                                await authManager.signOut()
                                dismiss()
                            }
                        }) {
                            HStack {
                                Text("Logout")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                        .buttonStyle(PlainButtonStyle())

                        Spacer() // To push content to top if ScrollView is not full
                    }
                    .padding() // Padding for the content VStack
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar) // Hide default navigation bar if using custom one
            #endif
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
