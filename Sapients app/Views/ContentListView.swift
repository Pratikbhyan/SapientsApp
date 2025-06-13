import SwiftUI

struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    @State private var presentingContentDetail: Content? = nil
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @StateObject private var subscriptionService = SubscriptionService.shared

    private var filteredContents: [Content] {
        return repository.contents.sorted { $0.effectiveSortDate < $1.effectiveSortDate }
    }
    
    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            // Top Bar: Settings Button
            HStack {
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

            Group {
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
