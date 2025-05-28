import SwiftUI

struct ContentListView: View {
    // State variables for Quick Notes button customization
    @State private var quickNotesButtonWidth: CGFloat = 160
    @State private var quickNotesButtonHeight: CGFloat = 50
    @State private var quickNotesButtonCornerRadius: CGFloat = 25
    @State private var quickNotesButtonOffsetX: CGFloat = -20 // From trailing edge
    @State private var quickNotesButtonOffsetY: CGFloat = -30 // From bottom edge
    
    @State private var isQuickNotesActive = false // For NavigationLink activation
    @StateObject private var repository = ContentRepository()
    
    enum Tab {
        case library
        case favourites
    }
    @State private var selectedTab: Tab = .library
    
    var body: some View {
        // The NavigationView should remain the root for navigation to work correctly
        // with the NavigationLink we're adding.
        NavigationView {
            ZStack(alignment: .bottomTrailing) { // ZStack to overlay button
                VStack(spacing: 0) { // Main VStack for Picker and content area
                Picker("Choose a section", selection: $selectedTab) {
                    Text("Library").tag(Tab.library)
                    Text("Favourites").tag(Tab.favourites)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 5)

                Group { // Group to switch content based on tab
                    if selectedTab == .library {
                        // Library content logic
                        if repository.isLoading {
                            ProgressView("Loading content...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        // Removed the error display block
                        else if repository.contents.isEmpty {
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
                            List(repository.contents) { content in
                                NavigationLink(destination: ContentDetailView(content: content)) {
                                    ContentRowView(content: content, repository: repository)
                                }
                            }
                            .refreshable {
                                await repository.fetchAllContent()
                            }
                        }
                    } else if selectedTab == .favourites {
                        // Favourites placeholder view
                        VStack {
                            Image(systemName: "heart.fill")
                                .font(.largeTitle)
                                .foregroundColor(.pink)
                            Text("Your Favourites")
                                .font(.headline)
                            Text("Content you mark as favourite will appear here.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } // End Group for tabbed content
            } // End VStack for main content
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure VStack takes available space

            // Quick Notes Button
            NavigationLink(destination: QuickNotesView(), isActive: $isQuickNotesActive) {
                 EmptyView() // Invisible link, activated by button tap
            }
            .hidden()

            Button(action: {
                isQuickNotesActive = true // Activate the NavigationLink
            }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Quick Notes")
                }
                .font(.headline)
                .padding()
                .frame(width: quickNotesButtonWidth, height: quickNotesButtonHeight)
                .background(Color(red: 135/255.0, green: 206/255.0, blue: 245/255.0, opacity: 0.9)) // Example background
                .foregroundColor(.white)
                .cornerRadius(quickNotesButtonCornerRadius)
                .shadow(radius: 5)
            }
            .offset(x: quickNotesButtonOffsetX, y: quickNotesButtonOffsetY)
            
            } // End ZStack
        } // End NavigationView
        // .task should ideally be on a view inside NavigationView if it's specific to its content,
        // or on the NavigationView itself if it's for the whole navigation stack setup.
        // Keeping it on NavigationView for now as per original structure.
        .task { // .task modifier applied to NavigationView
            await repository.fetchAllContent()
        }
    }
}

// ContentRowView and ContentDetailView (if it exists) would remain unchanged.
// ContentRepository would also remain unchanged in its core logic for fetching and error handling,
// but the UI just won't display the error.

struct ContentRowView: View {
    let content: Content
    let repository: ContentRepository
    
    var body: some View {
        HStack {
            // Thumbnail Image
            if let imageUrl = content.imageUrl,
               let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
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
            
            // Content Info
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
                
                Text(content.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Play indicator
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentListView()
}
