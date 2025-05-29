import SwiftUI

struct ContentListView: View {
    // State variables for Quick Notes button customization
    @State private var quickNotesButtonWidth: CGFloat = 160
    @State private var quickNotesButtonHeight: CGFloat = 50
    @State private var quickNotesButtonCornerRadius: CGFloat = 25
    @State private var quickNotesButtonOffsetX: CGFloat = -20 // From trailing edge
    @State private var quickNotesButtonOffsetY: CGFloat = -30 // From bottom edge
    
    @State private var showingQuickNotesSheet = false // For .sheet presentation
    @StateObject private var repository = ContentRepository()
    @StateObject private var favoritesService = FavoritesService.shared

    init() {
        print("[DIAG] ContentListView INIT")
    }
    
    enum Tab {
        case library
        case favourites
    }
    @State private var selectedTab: Tab = .library

    private var filteredContents: [Content] {
        if selectedTab == .library {
            return repository.contents
        } else {
            return repository.contents.filter { favoritesService.isFavorite(contentId: $0.id) }
        }
    }
    
    var body: some View {
        let _ = print("[DIAG] ContentListView BODY")
        // The NavigationView that was previously here has been removed.
        // Sapients_appApp.swift (or the parent view) should provide the NavigationView.
        
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Picker("Choose a section", selection: $selectedTab) {
                    Text("Library").tag(Tab.library)
                    Text("Favourites").tag(Tab.favourites)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 5)

                Group {
                    if selectedTab == .library {
                        if repository.isLoading && repository.contents.isEmpty {
                            ProgressView("Loading content...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if repository.contents.isEmpty {
                            VStack {
                                Image(systemName: "music.note.list")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No content available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Check back later for new content")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(filteredContents) { content in // Use filteredContents here for Library tab too
                                NavigationLink(destination: ContentDetailView(content: content)) {
                                    ContentRowView(content: content, repository: repository)
                                }
                            }
                            .refreshable {
                                await repository.fetchAllContent()
                            }
                        }
                    } else if selectedTab == .favourites {
                        if filteredContents.isEmpty {
                            VStack {
                                Image(systemName: "heart.slash.fill") // Different icon for empty state
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No Favourites Yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Tap the heart on an item to add it to your favourites.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List(filteredContents) { content in // Use filteredContents for Favourites tab
                                NavigationLink(destination: ContentDetailView(content: content)) {
                                    ContentRowView(content: content, repository: repository)
                                }
                            }
                            // Optional: Add .refreshable here if you want to pull-to-refresh favorites,
                            // though it might not be necessary if FavoritesService updates drive changes.
                        }
                    }
                } // End Group
            } // End VStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(action: {
                showingQuickNotesSheet = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Quick Notes")
                }
                .font(.headline)
                .padding()
                .frame(width: quickNotesButtonWidth, height: quickNotesButtonHeight)
                .background(Color(red: 135/255.0, green: 206/255.0, blue: 245/255.0, opacity: 0.9))
                .foregroundColor(.white)
                .cornerRadius(quickNotesButtonCornerRadius)
                .shadow(radius: 5)
            }
            .offset(x: quickNotesButtonOffsetX, y: quickNotesButtonOffsetY)
            
        } // End ZStack
        .sheet(isPresented: $showingQuickNotesSheet) {
            QuickNotesView()
        }
        // Example: .navigationTitle("Library") // Set this in Sapients_appApp.swift on the NavigationView
        .task {
            if repository.contents.isEmpty {
                 await repository.fetchAllContent()
            }
        }
        .onAppear {
            print("[DIAG] ContentListView ON_APPEAR (ZStack level)")
        }
        .onDisappear {
            print("[DIAG] ContentListView ON_DISAPPEAR (ZStack level)")
        }
    }
}

struct ContentRowView: View {
    let content: Content
    @ObservedObject var repository: ContentRepository
    
    var body: some View {
        HStack {
            if let imageUrl = content.imageUrl,
               let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.2))
                        .overlay(ProgressView().scaleEffect(0.8))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .padding(15)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let description = content.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Text(content.publishOn ?? content.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct ContentListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { // Add NavigationView here for preview to work correctly
            ContentListView()
        }
    }
}
#endif
