import SwiftUI
import UIKit // Needed for UIApplication

// Helper struct for App Icon options
// Helper struct for App Icon options
struct AppIconOption: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    let iconName: String? // nil for primary icon
    let previewImageName: String // Name of the preview image in Assets.xcassets

    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
        hasher.combine(iconName)
        hasher.combine(previewImageName)
    }

    static func == (lhs: AppIconOption, rhs: AppIconOption) -> Bool {
        return lhs.displayName == rhs.displayName && lhs.iconName == rhs.iconName && lhs.previewImageName == rhs.previewImageName
    }
}

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var notificationsEnabled = true
    @State private var isShowingSubscriptionSheet = false
    @Environment(\.dismiss) var dismiss
    
    // MARK: - App Icon Changer State and Options
    // Store the *name* of the selected icon (or nil for default)
    @State private var currentAlternateIconName: String? // Will be initialized in .onAppear
    
    // This remains the source of truth for available options
    private let iconOptions: [AppIconOption] = [
        // IMPORTANT: For each option below, ensure an IMAGE SET (not App Icon Set)
        // exists in Assets.xcassets with the EXACT name specified in 'previewImageName'.
        .init(displayName: "Sapients Default", iconName: nil, previewImageName: "p_primary"), // Represents the primary app icon.
        .init(displayName: "Sky", iconName: "AppIcon-sky", previewImageName: "p_sky"),
        .init(displayName: "Earth", iconName: "AppIcon-earth", previewImageName: "p_earth"),
        .init(displayName: "Sunset", iconName: "AppIcon-sunset", previewImageName: "p_sunset"),
        .init(displayName: "Glow", iconName: "AppIcon-glow", previewImageName: "p_glow"),
        .init(displayName: "Bow", iconName: "AppIcon-bow", previewImageName: "p_bow"),
        .init(displayName: "Star", iconName: "AppIcon-star", previewImageName: "p_star"),
        .init(displayName: "Cement", iconName: "AppIcon-cement", previewImageName: "p_cement"),
        .init(displayName: "Tiffany", iconName: "AppIcon-tiffany", previewImageName: "p_tiffany")
    ]
    
    private func currentPreviewImageName() -> String {
        if let currentIconName = currentAlternateIconName {
            if let option = iconOptions.first(where: { $0.iconName == currentIconName }) {
                return option.previewImageName
            }
        }
        return iconOptions.first(where: { $0.iconName == nil })?.previewImageName ?? ""
    }
    
    private func currentIconDisplayName() -> String {
        if let currentIconName = currentAlternateIconName {
            if let option = iconOptions.first(where: { $0.iconName == currentIconName }) {
                return option.displayName
            }
        }
        return iconOptions.first(where: { $0.iconName == nil })?.displayName ?? ""
    }
    
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
        // REMOVED: NavigationView wrapper
        VStack(spacing: 0) { // This VStack is now the top-level view in the body
            // REMOVED: Custom Top Bar and Divider
            
            ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // Profile Section
                        HStack(spacing: 15) {
                            if let url = profilePictureURL {
                                CachedAsyncImage(url: url) {
                                    Image(systemName: "person.circle.fill") // Placeholder
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .foregroundColor(.gray)
                                }
                                .aspectRatio(contentMode: .fill) // Apply to CachedAsyncImage
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                            } else {
                                // Fallback if profilePictureURL is nil
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .foregroundColor(.gray)
                            }
                            
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
                            // print("Subscribe button tapped")
                            isShowingSubscriptionSheet = true
                        }) {
                            HStack {
                                Text("Subscribe")
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
                        .sheet(isPresented: $isShowingSubscriptionSheet) {
                            SubscriptionView()
                        }
                        
                        // Change App Icon Row
                        NavigationLink(destination: AppIconSelectionView(iconOptions: iconOptions, selectedIconName: $currentAlternateIconName)) {
                            HStack {
                                Text("App Icon")
                                    .foregroundColor(Color(UIColor.label))
                                Spacer()
                                // Display the preview of the currently selected icon
                                Image(currentPreviewImageName())
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 7)) // iOS icon shape for preview
                                // Text(currentIconDisplayName()) // Removed display name of selected icon
                                //     .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.1)) // Consistent with other rows
                        
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
                .onAppear { // Correctly attached to ScrollView
                    // Set the initial selected icon name based on the current app icon
                    self.currentAlternateIconName = UIApplication.shared.alternateIconName
                }
            // REMOVED: .toolbar(.hidden, for: .navigationBar)
        }
        // ADDED: Standard navigation modifiers to the VStack
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline) // Or .large, as preferred
    }
    
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            // Wrap in NavigationView for preview context if SettingsView expects to be in one
            NavigationView { 
                SettingsView()
            }
        }
    }
}
