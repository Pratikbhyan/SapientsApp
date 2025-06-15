import SwiftUI
import Combine

/// Publishes keyboard visibility changes so views can react in real‑time.
final class KeyboardResponder: ObservableObject {
    @Published var isKeyboardShown: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        Publishers.Merge(willShow, willHide)
            .removeDuplicates()
            .sink { [weak self] value in
                self?.isKeyboardShown = value
            }
            .store(in: &cancellables)
    }
}

/// A simplified list view that makes every row a single `Button`, ensuring
/// reliable tap recognition across the entire row area and coordinates the
/// mini‑player with keyboard visibility.
struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    @State private var presentingContentDetail: Content? = nil
    @StateObject private var audioPlayer = AudioPlayerService.shared
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @StateObject private var subscriptionService = SubscriptionService.shared

    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var searchFieldFocused: Bool

    /// Observes keyboard notifications.
    @StateObject private var keyboard = KeyboardResponder()

    // MARK: - Stable suggestions
    @State private var stableSuggestedEpisodes: [Content] = []

    // MARK: - Filter helpers
    private var filteredContents: [Content] {
        let sorted = repository.contents.sorted { $0.createdAt < $1.createdAt }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter { $0.title.localizedCaseInsensitiveContains(searchText) || ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false) }
    }

    // MARK: - Suggestions
    /// Call this once whenever we enter search mode, or when the
    /// repository finishes its first fetch.
    private func refreshSuggestedEpisodes() {
        let all = repository.contents
        stableSuggestedEpisodes = all.count <= 3 ? all
                                                : Array(all.shuffled().prefix(3))
    }

    /// The view now *reads* the state instead of mutating it
    private var suggestedEpisodes: [Content] { stableSuggestedEpisodes }

    // MARK: - Top Bar
    @ViewBuilder private var topBar: some View {
        HStack {
            if isSearchActive {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSearchActive = false
                        searchText = ""
                        searchFieldFocused = false
                        hideKeyboard()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search episodes…", text: $searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFieldFocused)
                        .submitLabel(.search)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            } else {
                Text("Sapients")
                    .font(.system(size: 28, weight: .heavy, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSearchActive = true
                    }
                    // Auto-focus search field after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        searchFieldFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Row Factory
    /// Simple, direct button approach - no fancy tricks
    private func contentButton(for content: Content, searchText: String = "") -> some View {
        Button(action: {
            presentingContentDetail = content
        }) {
            ContentRowView(content: content, repository: repository, searchText: searchText)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Main Content (Non-Search)
    @ViewBuilder private var mainContentArea: some View {
        if repository.isLoading && repository.contents.isEmpty {
            ProgressView("Loading content…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if repository.contents.isEmpty {
            EmptyState(image: "music.note.list", title: "No content available", subtitle: "Check back later for new content")
        } else {
            ScrollViewReader { proxy in
                List {
                    ForEach(filteredContents) { content in
                        simpleContentRow(for: content)
                            .id(content.id)
                    }
                }
                .listStyle(.plain)
                .refreshable { await repository.fetchAllContent() }
                .onAppear {
                    if let last = filteredContents.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: filteredContents) { _, new in
                    if let last = new.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Overlay
    @ViewBuilder private var searchOverlay: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search header
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSearchActive = false
                            searchText = ""
                            searchFieldFocused = false
                            hideKeyboard()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search episodes…", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($searchFieldFocused)
                            .submitLabel(.search)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(10)

                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Search content
                searchContentArea
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemBackground))
            .onTapGesture {
                if searchFieldFocused {
                    searchFieldFocused = false
                }
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Search Content Area
    @ViewBuilder private var searchContentArea: some View {
        if searchText.isEmpty {
            // "You may like" section - completely separate
            suggestionsSection
        } else if filteredContents.isEmpty {
            EmptyState(image: "magnifyingglass", title: "No results found", subtitle: "Try searching with different keywords")
        } else {
            // Search results - completely separate
            searchResultsSection
        }
    }
    
    // MARK: - Suggestions Section
    @ViewBuilder private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You may like")
                .font(.headline)
                .padding(.horizontal)

            if suggestedEpisodes.isEmpty {
                EmptyState(image: "music.note.list", title: "No episodes available yet")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(suggestedEpisodes) { content in
                            Button(action: {
                                presentingContentDetail = content
                            }) {
                                ContentRowView(content: content, repository: repository, searchText: "")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    // MARK: - Search Results Section
    @ViewBuilder private var searchResultsSection: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredContents) { content in
                    Button(action: {
                        presentingContentDetail = content
                    }) {
                        ContentRowView(content: content, repository: repository, searchText: searchText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Simple Content Row
    private func simpleContentRow(for content: Content, searchText: String = "") -> some View {
        Button(action: {
            presentingContentDetail = content
        }) {
            ContentRowView(content: content, repository: repository, searchText: searchText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Main Navigation View - always present
            NavigationView {
                VStack(spacing: 0) {
                    topBar
                    
                    // Only show main content when NOT searching
                    if !isSearchActive {
                        mainContentArea
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationBarHidden(true)
                .background(Color(UIColor.systemBackground))
            }
            .navigationViewStyle(.stack)
            
            // Search overlay - completely separate
            if isSearchActive {
                searchOverlay
            }
        }
        .sheet(item: $presentingContentDetail) { content in
            ContentDetailView(content: content, repository: repository)
                .environmentObject(audioPlayer)
                .environmentObject(miniPlayerState)
        }
        .task {
            if repository.contents.isEmpty { await repository.fetchAllContent() }
        }
        // When search is activated
        .onChange(of: isSearchActive) { _, active in
            if active { refreshSuggestedEpisodes() }
        }
        // When content first arrives from the backend
        .onReceive(repository.$contents) { _ in
            if stableSuggestedEpisodes.isEmpty { refreshSuggestedEpisodes() }
        }
        // Coordinate the mini‑player with keyboard visibility
        .onReceive(keyboard.$isKeyboardShown) { shown in
            if shown {
                miniPlayerState.isVisible = false
            } else {
                // Only show the mini‑player if there is something playing to avoid a blank bar.
                miniPlayerState.isVisible = audioPlayer.currentContent != nil
            }
        }
    }

    // MARK: - Helpers
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Reusable Empty State
private struct EmptyState: View {
    let image: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: image)
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
        HStack(alignment: .top, spacing: 12) {
            // Image Section
            if let imageUrlString = content.imageUrl,
               let imageURL = repository.getPublicURL(for: imageUrlString, bucket: "images") {
                CachedAsyncImage(url: imageURL) {
                    DefaultPlaceholder()
                        .frame(width: 60, height: 60)
                }
                .aspectRatio(contentMode: .fill)
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
                    .frame(width: 60, height: 60)
            }

            // Content Section
            VStack(alignment: .leading, spacing: 6) {
                highlightedText(content.title, searchText: searchText)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let description = content.description {
                    highlightedText(description, searchText: searchText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(content.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
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
        NavigationView { ContentListView() }
            .environmentObject(MiniPlayerState(player: AudioPlayerService.shared))
    }
}
#endif
