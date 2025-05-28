//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI

@main
struct Sapients_appApp: App {
    @State private var isUserLoggedIn: Bool = false // Or load from Keychain/UserDefaults

    var body: some Scene {
        WindowGroup {
            if isUserLoggedIn {
                TabView {
                    // Tab 1: Now Playing (loads daily content)
                    DailyContentViewLoader()
                        .tabItem {
                            Label("Now Playing", systemImage: "play.circle.fill")
                        }

                    // Tab 2: Content List (Browse)
                    NavigationView { // This NavigationView is for the Library tab
                        ContentListView() // ContentListView now correctly has no internal NavigationView
                    }
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }
                } // Closes TabView
            } else {
                LoginView(isUserLoggedIn: $isUserLoggedIn)
            }
        }
    }
}
