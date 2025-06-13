import SwiftUI

struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    @State private var presentingContentDetail: Content? = nil
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    @State private var searchText = ""
    @State private var isSearchActive = false

    private var filteredContents: [Content] {
        let allContents = repository.contents.sorted { $0.effectiveSortDate < $1.effectiveSortDate }
        
        if searchText.isEmpty {
            return allContents
        } else {
            return allContents.filter { content in
                content.title.localizedCaseInsensitiveContains(searchText) ||
                (content.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private var suggestedEpisodes: [Content] {
        let allContents = repository.contents
        if allContents.count <= 3 {
            return allContents
        } else {
            return Array(allContents.shuffled().prefix(3))
        }
    }
    
    @ViewBuilder
    private var topBar: some View {
        HStack {
            if isSearchActive {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSearchActive = false
                        searchText = ""
                        hideKeyboard()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    
                    TextField("Search episodes...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                }
            } else {
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSearchActive = true
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                }
                
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.accentColor)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        if isSearchActive {
            if searchText.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("You may like")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    if suggestedEpisodes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("No episodes available yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(suggestedEpisodes) { content in
                            Button(action: {
                                self.presentingContentDetail = content
                            }) {
                                ContentRowView(
                                    content: content,
                                    repository: repository,
                                    searchText: ""
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .listStyle(.plain)
                    }
                }
            } else if filteredContents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("No results found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Try searching with different keywords")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredContents) { content in
                    Button(action: {
                        self.presentingContentDetail = content
                    }) {
                        ContentRowView(
                            content: content,
                            repository: repository,
                            searchText: searchText
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(.plain)
            }
        } else {
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
                            ContentRowView(
                                content: content,
                                repository: repository,
                                searchText: ""
                            )
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
                .listStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            topBar
            contentArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            if isSearchActive {
                hideKeyboard()
            }
        }
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentRowView: View {
    let content: Content
    @ObservedObject var repository: ContentRepository
    let searchText: String
    
    init(content: Content, repository: ContentRepository, searchText: String = "") {
        self.content = content
        self.repository = repository
        self.searchText = searchText
    }
    
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
                    highlightedText(content.title, searchText: searchText)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                if let description = content.description {
                    highlightedText(description, searchText: searchText)
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
    
    @ViewBuilder
    private func highlightedText(_ text: String, searchText: String) -> some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            let attributedString = highlightMatches(in: text, searchText: searchText)
            Text(AttributedString(attributedString))
        }
    }
    
    private func highlightMatches(in text: String, searchText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.count)
        
        attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        
        if !searchText.isEmpty {
            let searchRange = text.range(of: searchText, options: .caseInsensitive)
            if let searchRange = searchRange {
                let nsRange = NSRange(searchRange, in: text)
                attributedString.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: nsRange)
                attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: nsRange)
            }
        }
        
        return attributedString
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
