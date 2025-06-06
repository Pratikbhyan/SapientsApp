import SwiftUI

struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    @StateObject private var favoritesService = FavoritesService.shared
    @State private var presentingContentDetail: Content? = nil
    @StateObject private var audioPlayer = AudioPlayerService.shared // Ensure access to the player
    @EnvironmentObject var miniPlayerState: MiniPlayerState // Access to mini-player state

    init() {
        print("[DIAG] ContentListView INIT")
    }
    
    enum Tab {
        case library
        case favourites
    }
    @State private var selectedTab: Tab = .library // Keep this for logic
    @State private var selectedSegmentIndex: Int = 0 // 0 for Library, 1 for Favourites

    private var filteredContents: [Content] {
        let allContents = repository.contents
        if selectedTab == .library {
            return allContents.sorted { $0.effectiveSortDate < $1.effectiveSortDate }
        } else {
            return allContents.filter { favoritesService.isFavorite(contentId: $0.id) }.sorted { $0.effectiveSortDate < $1.effectiveSortDate }
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            // Top Bar: Segmented Control and Settings Button
            HStack {
                Spacer() // Pushes segmented control to center
                StylishSegmentedControl(
                    selection: $selectedSegmentIndex,
                    items: [
                        (icon: nil, title: "Library"),
                        (icon: nil, title: "Favourites")
                    ]
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.9) // Constrain width to allow centering
                Spacer() // Pushes settings button to the right
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal) // Horizontal padding for the whole bar
            .padding(.top, 8)     // Top padding for the bar
            .padding(.bottom, 10) // Bottom padding after the bar
            .onChange(of: selectedSegmentIndex) { _, newIndex in
                selectedTab = (newIndex == 0) ? .library : .favourites
            }

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
                        ScrollViewReader { scrollViewProxy in
                            List(filteredContents) { content in
                                Button(action: {
                                    self.presentingContentDetail = content
                                }) {
                                    ContentRowView(content: content, repository: repository)
                                }
                                .buttonStyle(PlainButtonStyle()) // To make the whole row tappable like a NavLink
                                .id(content.id) // Keep for ScrollViewReader
                            }
                            .refreshable {
                                await repository.fetchAllContent()
                            }
                            .onAppear {
                                if let lastItem = filteredContents.last {
                                    scrollViewProxy.scrollTo(lastItem.id, anchor: .bottom)
                                }
                            }
                            .onChange(of: filteredContents) { _, newContents in
                                if let lastItem = newContents.last {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        scrollViewProxy.scrollTo(lastItem.id, anchor: .bottom)
                                    }
                                }
                            }
                        } // End ScrollViewReader
                    }
                } else if selectedTab == .favourites {
                    if filteredContents.isEmpty {
                        VStack {
                            Image(systemName: "heart.slash.fill")
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
                        List(filteredContents) { content in
                            Button(action: {
                                self.presentingContentDetail = content
                            }) {
                                ContentRowView(content: content, repository: repository)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } // End Group
            .listStyle(.plain) // Apply listStyle to the Group
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        let _ = print("[DIAG] ContentListView BODY")
        
        listContent
            .sheet(item: $presentingContentDetail) { contentToPresent in
                ContentDetailView(content: contentToPresent, repository: repository)
                    .environmentObject(audioPlayer)
                    .environmentObject(miniPlayerState)
                    .onDisappear {
                        print("[DIAG] ContentDetailView via sheet DISMISSED")
                        // Mini-player visibility is now handled globally by MiniPlayerState and Sapients_appApp
                    }
            }
            .task {
                if repository.contents.isEmpty {
                     await repository.fetchAllContent()
                }
            }
            .onAppear {
                print("[DIAG] ContentListView ON_APPEAR (listContent level)")
            }
            .onDisappear {
                print("[DIAG] ContentListView ON_DISAPPEAR (listContent level)")
            }
    }
}

struct ContentRowView: View {
    let content: Content
    @ObservedObject var repository: ContentRepository
    
    var body: some View {
        let _ = print("[ContentRowView] Content ID: \(content.id), Title: \(content.title), Image URL String: \(content.imageUrl ?? "nil")") // DIAGNOSTIC
        HStack {
            if let imageUrlString = content.imageUrl,
               let imageURL = repository.getPublicURL(for: imageUrlString, bucket: "images") {
                    let _ = print("[ContentRowView] Generated Public URL for \(imageUrlString): \(imageURL)") // DIAGNOSTIC
                CachedAsyncImage(url: imageURL) {
                    // This is the placeholder view from CachedAsyncImage
                    DefaultPlaceholder()
                        .frame(width: 60, height: 60) // Apply frame to placeholder as well
                }
                .aspectRatio(contentMode: .fill) // Apply to the image if loaded
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

// Definition for the StylishSegmentedControl
fileprivate struct StylishSegmentedControlItem: Identifiable {
    let id = UUID()
    let icon: String?
    let title: String
}

// Updated StylishSegmentedControl with centered pill design
fileprivate struct StylishSegmentedControl: View {
    @Binding var selection: Int
    let items: [StylishSegmentedControlItem]
    @Namespace private var animation

    init(selection: Binding<Int>, items: [(icon: String?, title: String)]) {
        self._selection = selection
        self.items = items.map { StylishSegmentedControlItem(icon: $0.icon, title: $0.title) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.1)) {
                        selection = index
                    }
                }) {
                    HStack(spacing: 6) {
                        if let iconName = items[index].icon {
                            Image(systemName: iconName)
                                .font(.system(size: 14, weight: .medium))
                        }
                        Text(items[index].title)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .foregroundColor(selection == index ? .white : .primary)
                    .background(
                        ZStack {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0)) // Sky blueish color
                                    .matchedGeometryEffect(id: "selectedBackground", in: animation)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle()) // Remove default button styling
            }
        }
        .padding(4) // Padding inside the overall container
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(uiColor: .systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .frame(maxWidth: 280) // Constrain width to center it better
    }
}
