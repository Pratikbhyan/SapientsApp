//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI
import GoogleSignIn
import FirebaseCore
import FirebaseAuth

// Enum to identify tabs
enum TabIdentifier {
    case library, highlights
}

@main
struct Sapients_appApp: App {
    @StateObject private var authManager = FirebaseAuthManager.shared
    @StateObject private var contentRepository = ContentRepository()
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @StateObject private var miniPlayerState = MiniPlayerState(player: AudioPlayerService.shared)
    @StateObject private var quickNotesRepository = QuickNotesRepository.shared
    @StateObject private var storeKit = StoreKitService.shared
    @StateObject private var theme = ThemeManager()
    @State private var selectedTab: TabIdentifier = .library
    @State private var isLoadingTranscription = false

    init() {
        FirebaseApp.configure()
        configureGoogleSignIn()
    }

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottom) {
                mainContent
                
                // Unified draggable full-player ↔︎ mini-player container
                MiniPlayerBarView()
            }
            .environmentObject(authManager)
            .environmentObject(contentRepository)
            .environmentObject(audioPlayer)
            .environmentObject(miniPlayerState)
            .environmentObject(quickNotesRepository)
            .environmentObject(storeKit)
            .environmentObject(theme)
            .preferredColorScheme(theme.selection == .darkMono ? .dark : (theme.selection == .lightMono ? .light : nil))
            .fullScreenCover(isPresented: $miniPlayerState.isPresentingFullPlayer) {
                fullPlayerSheet
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if authManager.isAuthenticated {
            TabView(selection: $selectedTab) {
                CollectionsListView()
                    .tag(TabIdentifier.library)
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                
                QuickNotesView()
                    .tag(TabIdentifier.highlights)
                    .tabItem {
                        Label("Highlights", systemImage: "highlighter")
                    }
            }
            .tint(.accentColor)
            .onAppear {
                updateTabBarAppearance()
            }
            .onChange(of: theme.selection) { _ in
                updateTabBarAppearance()
            }

        } else {
            LoginView()
        }
    }
    
    @ViewBuilder
    private var fullPlayerSheet: some View {
        if let contentToPlay = audioPlayer.currentContent {
            // Full-screen player sheet without the unavailable BlurredBackgroundView.
                PlayingView(
                    content: contentToPlay,
                    repository: contentRepository,
                    audioPlayer: audioPlayer,
                    isLoadingTranscription: $isLoadingTranscription,
                    onDismissTapped: {
                        miniPlayerState.dismissFullPlayer()
                    }
                )
            .ignoresSafeArea() // ensure player covers the entire screen
        }
    }
    
    // Google Sign-In configuration
    private func configureGoogleSignIn() {
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let clientID = dict["GIDClientID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("Google Sign-In configured with CLIENT_ID from Info.plist: \(clientID)")
            return
        }
        
        if let path = Bundle.main.path(forResource: "GoogleService-Info 2", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let idFromPlist = dict["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: idFromPlist)
            print("Google Sign-In configured with CLIENT_ID from GoogleService-Info.plist: \(idFromPlist)")
        } else {
            let hardcodedClientID = "453563946840-cg1tu8jkc4uomltcqooc5adifkqg8f4i.apps.googleusercontent.com"
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: hardcodedClientID)
            print("Google Sign-In configured with HARDCODED CLIENT_ID: \(hardcodedClientID). Consider fixing Info.plist or GoogleService-Info.plist.")
        }
    }

    // removed hard-coded UIUserInterfaceStyle override – handled by ThemeManager
    
    // Fix: Extract tab bar appearance configuration into a separate function
    private func updateTabBarAppearance() {
        let isLight = theme.selection != .darkMono && (theme.selection == .lightMono || UITraitCollection.current.userInterfaceStyle == .light)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        // Use system background colors that automatically adapt to theme
        tabBarAppearance.backgroundColor = UIColor.systemBackground

        // Use system colors that automatically adapt to light/dark mode
        let normalColor = UIColor.systemGray
        let selectedColor = UIColor.label

        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = normalColor
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        tabBarAppearance.compactInlineLayoutAppearance = tabBarAppearance.stackedLayoutAppearance

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

extension Notification.Name {
    static let dailyEpisodeNotificationTapped = Notification.Name("dailyEpisodeNotificationTapped")
}
