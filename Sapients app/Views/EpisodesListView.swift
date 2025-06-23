import SwiftUI
import Supabase
import UIKit

struct EpisodesListView: View {
    let collection: Collection
    var coverNamespace: Namespace.ID? = nil
    
    @State private var episodes: [Content] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    // Controls the once-per-view slide-up animation for the carousel
    @State private var hasAnimatedCarousel = false
    
    // Shared services from app environment
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @EnvironmentObject var contentRepo: ContentRepository
    
    private let supabase = SupabaseManager.shared.client
    
    @State private var dominant: Color = .black
    
    var body: some View {
        let headerHeight: CGFloat = 150
        ZStack(alignment: .top) {
            // Scrollable content behind the header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Spacer so initial content starts just below the header
                    Color.clear.frame(height: headerHeight)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !episodes.isEmpty {
                        EpisodeCarousel(episodes: episodes)
                            .padding(.top, 5)
                            .offset(y: hasAnimatedCarousel ? 0 : 300)
                            .opacity(hasAnimatedCarousel ? 1 : 0)
                            .onAppear {
                                guard !hasAnimatedCarousel else { return }
                                withAnimation(.easeOut(duration: 0.4)) { hasAnimatedCarousel = true }
                            }
                    } else if let _ = errorMessage {
                        Text("Failed to load episodes")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        Text("No episodes yet")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
            .ignoresSafeArea(edges: .top) // allow content to slide under status bar/header

            // Fixed header overlay
            HeaderView(collection: collection, coverNamespace: coverNamespace)
                .frame(height: headerHeight)
                .ignoresSafeArea(edges: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task { await loadEpisodes() }
    }
    
    // MARK: - Networking
    @MainActor
    private func loadEpisodes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: [Content] = try await supabase
                .from("episodes")
                .select("id, title, description, audio_url, image_url, created_at, transcript_url, collection_id")
                .eq("collection_id", value: collection.id.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            self.episodes = result
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Header
private struct HeaderView: View {
    let collection: Collection
    var coverNamespace: Namespace.ID?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        GeometryReader { geo in
            let isLight = scheme == .light
            let bgColor: Color = isLight ? .black : .white
            let textColor: Color = isLight ? .white : .black

            ZStack(alignment: .topLeading) {
                bgColor
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea(edges: .top)

                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(textColor)
                        .frame(width: 44, height: 44)
                        .background(bgColor.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(.leading, 16)
                .padding(.top, geo.safeAreaInsets.top + 44)

                VStack {
                    Spacer()
                    Text(collection.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, Tokens.Spacing.s)
                }
            }
        }
    }
}

// MARK: - Carousel
private struct EpisodeCarousel: View {
    let episodes: [Content]
    private let cardWidthFactor: CGFloat = 0.9

    var body: some View {
        // Calculate width based on the device screen to avoid GeometryReader inside ScrollView
        let screenWidth = UIScreen.main.bounds.width
        let cardWidth = screenWidth * cardWidthFactor
        let cardPadding = (screenWidth - cardWidth) / 2

        TabView(selection: .constant(0)) {
            ForEach(Array(episodes.enumerated()), id: \ .offset) { index, ep in
                VStack(spacing: 0) {
                    EpisodeCard(episode: ep, cardWidth: cardWidth)
                    Spacer() // pushes card to top of fixed frame
                }
                .padding(.horizontal, cardPadding)
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        // Give the carousel a consistent height: 60% of screen + extra space for title spacing
        .frame(height: UIScreen.main.bounds.height * 0.6 + 60)
    }
}

private struct EpisodeCard: View {
    let episode: Content
    let cardWidth: CGFloat
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @EnvironmentObject var contentRepo: ContentRepository
    
    @State private var dominant: Color = .black
    @State private var textColor: Color = .white
    
    var body: some View {
        VStack(spacing: 16) {
            // --- KEY LAYOUT CHANGE ---
            // Cover image with overlayed play button (overlay doesn't affect layout below)
            cover
                .frame(width: cardWidth, height: cardWidth)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(alignment: .bottomTrailing) {
                    Button(action: play) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 3)
                    }
                    .padding(12)
                }

            // Title & description
            VStack(alignment: .center, spacing: 6) {
                Text(episode.title)
                    .font(.custom("Didot-Bold", size: 24))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if let desc = episode.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .frame(width: cardWidth * 0.9)
        }
        .frame(width: cardWidth)
    }
    
    // MARK: - Helpers
    @ViewBuilder private var cover: some View {
        if let rawPath = episode.imageUrl {
            // Trim whitespace/newlines and strip leading "images/" if present
            let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let path = trimmed.hasPrefix("images/") ? String(trimmed.dropFirst("images/".count)) : trimmed

            if let url = try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: path) {
                CachedAsyncImage(url: url) {
                    Color.gray.opacity(0.3)
                }
            } else {
                Color.gray.opacity(0.3)
            }
        } else {
            Color.gray.opacity(0.3)
        }
    }

    private func extractColors() {
        guard dominant == .black else { return } // avoid repeating work
        // Fetch the thumbnail image data to compute dominant color off-main-thread
        Task.detached(priority: .utility) {
            guard let urlStr = episode.imageUrl,
                  let url = try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: urlStr),
                  let data = try? Data(contentsOf: url),
                  let uiImage = UIImage(data: data),
                  let dom = ImageColorExtractor.dominantColor(from: uiImage) else { return }

            let inverted = isDark(color: dom) ? Color.white : Color.black

            await MainActor.run {
                self.dominant = dom
                self.textColor = inverted
            }
        }
    }

    private func isDark(color: Color) -> Bool {
        let uiColor = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        // luminance calc
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        return lum < 0.5
    }

    private func play() {
        // Prevent multiple simultaneous taps
        guard !miniPlayerState.isPresentingFullPlayer else { return }
        
        // Build public URL for audio
        var audioURL: URL? = nil
        if episode.audioUrl.starts(with: "http") {
            audioURL = URL(string: episode.audioUrl)
        } else {
            do {
                audioURL = try SupabaseManager.shared.client.storage.from("audio").getPublicURL(path: episode.audioUrl)
            } catch {
                print("❌ Failed to get audio URL: \(error)")
                return
            }
        }
        
        guard let url = audioURL else {
            print("❌ Invalid audio URL for episode: \(episode.title)")
            return
        }
        
        // Load audio and present player
        audioPlayer.loadAudio(from: url, for: episode, autoPlay: true)
        
        // Fetch transcriptions in background
        Task {
            await contentRepo.fetchTranscriptions(for: episode.id, from: episode.transcriptionUrl)
        }
        
        // Present full player immediately
        miniPlayerState.presentFullPlayer()
    }
}

// helper
private func getCollectionImageURL(for collection: Collection) -> URL? {
    if let path = collection.imageUrl {
        if path.hasPrefix("collections/") {
            let clean = String(path.dropFirst("collections/".count))
            return try? SupabaseManager.shared.client.storage.from("collections").getPublicURL(path: clean)
        }
        return try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: path)
    }
    return nil
}

// Shape for rounding only bottom corners
struct BottomRoundedShape: Shape {
    var radius: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Shape for rounding only top corners
struct TopRoundedShape: Shape {
    var radius: CGFloat = 16
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}


#Preview("EpisodeCarousel") {
    NavigationStack {
        EpisodeCarousel(episodes: Array(repeating: Content(id: UUID(), title: "Sample Episode", description: "Sample Description", audioUrl: "", imageUrl: nil, createdAt: Date(), transcriptionUrl: nil, collectionId: UUID()), count: 5))
    }
}
