//
//  Sapients_appApp.swift
//  Sapients app
//
//  Created by Pratik Bhyan on 23/05/25.
//

import SwiftUI

@main
struct Sapients_appApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                // Tab 1: Now Playing (loads daily content)
                DailyContentViewLoader()
                    .tabItem {
                        Label("Now Playing", systemImage: "play.circle.fill")
                    }

                // Tab 2: Content List (Browse)
                NavigationView {
            ContentListView()
                }
                .tabItem {
                    Label("Browse", systemImage: "music.note.list")
                }
            }
        }
    }
}
