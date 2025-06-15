import SwiftUI
import UIKit // Needed for UIApplication
import UserNotifications
import Supabase

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
    @StateObject private var storeKit = StoreKitService.shared
    @State private var isShowingSubscriptionSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var showingSupport = false
    @State private var showingFeedback = false
    @Environment(\.dismiss) var dismiss
    
    // MARK: - App Icon Changer State and Options
    @State private var currentAlternateIconName: String? // Will be initialized in .onAppear
    
    private let iconOptions: [AppIconOption] = [
        // IMPORTANT: For each option below, ensure an IMAGE SET (not App Icon Set)
        // exists in Assets.xcassets with the EXACT name specified in 'previewImageName'.
        .init(displayName: "Sapients Default", iconName: nil, previewImageName: "p_primary"), // Represents the primary app icon.
        .init(displayName: "Sky", iconName: "AppIcon-sky", previewImageName: "p_sky"),
        .init(displayName: "Earth", iconName: "AppIcon-earth", previewImageName: "p_earth"),
        .init(displayName: "Sunset", iconName: "AppIcon-sunset", previewImageName: "p_sunset"),
        .init(displayName: "Glow", iconName: "AppIcon-glow", previewImageName: "p_glow"),
        .init(displayName: "Bow", iconName: "AppIcon-bow", previewImageName: "p_glow"),
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
    
    private var displayName: String {
        guard let user = authManager.user else { return "User" }
        let metadata = user.userMetadata

        // Prioritize full_name from metadata
        if let fullName = metadata["full_name"]?.stringValue, !fullName.isEmpty {
            return fullName
        }
        // Fallback to name from metadata (if you decide to store 'name' like givenName)
        if let name = metadata["name"]?.stringValue, !name.isEmpty {
            return name
        }
        // Fallback to user's primary email prefix
        if let email = user.email, !email.isEmpty {
            return String(email.split(separator: "@").first ?? "User")
        }
        // Fallback to generic "User"
        return "User"
    }
    
    private var profilePictureURL: URL? {
        guard let user = authManager.user else { return nil }
        let metadata = user.userMetadata
        
        // Check for common avatar/picture keys
        if let avatarURLString = metadata["avatar_url"]?.stringValue {
            return URL(string: avatarURLString)
        }
        // Google often uses "picture"
        if let pictureURLString = metadata["picture"]?.stringValue {
            return URL(string: pictureURLString)
        }
        // Apple Sign In does not provide a picture URL directly.
        // If Supabase populates a specific key for Apple's (non-existent) picture, add it here.
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Profile Section
                    HStack(spacing: 15) {
                        if let url = profilePictureURL {
                            CachedAsyncImage(url: url) {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .foregroundColor(.gray)
                            }
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
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

                    // Subscribe Row
                    HStack {
                        Text(storeKit.hasActiveSubscription ? "Subscribed" : "Subscribe")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: storeKit.hasActiveSubscription ? "checkmark.circle.fill" : "chevron.right")
                            .foregroundColor(storeKit.hasActiveSubscription ? .green : .gray)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        if !storeKit.hasActiveSubscription {
                            isShowingSubscriptionSheet = true
                        }
                    }
                    .sheet(isPresented: $isShowingSubscriptionSheet) {
                        SubscriptionView()
                    }
                    
                    // Change App Icon Row
                    NavigationLink(destination: AppIconSelectionView(iconOptions: iconOptions, selectedIconName: $currentAlternateIconName)) {
                        HStack {
                            Text("App Icon")
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                            Image(currentPreviewImageName())
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    
                    HStack {
                        Text("Send Feedback")
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                        Image(systemName: "envelope")
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        showingFeedback = true
                    }
                    .sheet(isPresented: $showingFeedback) {
                        FeedbackView()
                    }

                    // About
                    NavigationLink(destination: AboutView()) {
                        HStack {
                            Text("About Sapients")
                                .foregroundColor(Color(UIColor.label))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    
                    // Account
                    Text("Account")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    // Delete Account Row
                    HStack {
                        Text("Delete Account")
                            .font(.headline)
                            .foregroundColor(.red)
                        Spacer()
                        if authManager.isDeletingAccount {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        if !authManager.isDeletingAccount {
                            showingDeleteConfirmation = true
                        }
                    }
                    .disabled(authManager.isDeletingAccount)
                    .opacity(authManager.isDeletingAccount ? 0.6 : 1.0)
                    
                    // Logout Row
                    HStack {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(.red)
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
                    .onTapGesture {
                        Task {
                            await authManager.signOut()
                            dismiss()
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .onAppear {
                self.currentAlternateIconName = UIApplication.shared.alternateIconName
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone. All your data will be permanently removed.")
        }
        .alert("Error", isPresented: $showingDeleteError) {
            Button("OK") { }
        } message: {
            Text(deleteError ?? "An error occurred while deleting your account.")
        }
    }
    
    private func deleteAccount() async {
        do {
            try await authManager.deleteAccount()
            // User will be automatically signed out and redirected to login
        } catch {
            deleteError = error.localizedDescription
            showingDeleteError = true
        }
    }

    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                SettingsView()
            }
        }
    }
}
