import SwiftUI

struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    @StateObject private var favoritesService = FavoritesService.shared
    @State private var presentingContentDetail: Content? = nil
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    enum Tab {
        case library
        case favourites
    }
    @State private var selectedTab: Tab = .library
    @State private var selectedSegmentIndex: Int = 0

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
                Spacer()
                StylishSegmentedControl(
                    selection: $selectedSegmentIndex,
                    items: [
                        (icon: nil, title: "Library"),
                        (icon: nil, title: "Favourites")
                    ]
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                Spacer()
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 10)
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
                                .buttonStyle(PlainButtonStyle())
                                .id(content.id)
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
                        }
                    }
                } else if selectedTab == .favourites {
                    if favoritesService.isLoading {
                        ProgressView("Loading favorites...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredContents.isEmpty {
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
            }
            .listStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        NavigationView {
            listContent
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: $presentingContentDetail) { contentToPresent in
            ContentDetailView(content: contentToPresent, repository: repository)
                .environmentObject(audioPlayer)
                .environmentObject(miniPlayerState)
        }
        .task {
            if repository.contents.isEmpty {
                 await repository.fetchAllContent()
            }
        }
        .onAppear {
            Task {
                await favoritesService.refreshFavorites()
            }
        }
    }
}

struct ContentRowView: View {
    let content: Content
    @ObservedObject var repository: ContentRepository
    
    var body: some View {
        HStack {
            if let imageUrlString = content.imageUrl,
               let imageURL = repository.getPublicURL(for: imageUrlString, bucket: "images") {
                ZStack {
                    CachedAsyncImage(url: imageURL) {
                        DefaultPlaceholder()
                            .frame(width: 60, height: 60)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .clipped()
                }
            } else {
                ZStack {
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .padding(15)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(content.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
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
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct ContentListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContentListView()
        }
    }
}
#endif

fileprivate struct StylishSegmentedControlItem: Identifiable {
    let id = UUID()
    let icon: String?
    let title: String
}

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
                                    .fill(Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0))
                                    .matchedGeometryEffect(id: "selectedBackground", in: animation)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(uiColor: .systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .frame(maxWidth: 280)
    }
}
