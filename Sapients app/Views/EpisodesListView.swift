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
        let headerHeight: CGFloat = UIScreen.main.bounds.height * 0.22
        ScrollView(showsIndicators: false) {
            GeometryReader { geo in
                let y = geo.frame(in: .global).minY
                HeaderView(collection: collection, coverNamespace: coverNamespace)
                    .frame(width: UIScreen.main.bounds.width,
                           height: y > 0 ? headerHeight + y : headerHeight)
                    .offset(y: y > 0 ? -y : 0) // sticky & stretchy
            }
            .frame(height: headerHeight) // occupies space in scroll

            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !episodes.isEmpty {
                    EpisodeCarousel(episodes: episodes)
                        .padding(.top, 24)
                        .padding(.bottom, 60) // space for home indicator
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
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

struct EpisodeTile: View {
    let episode: Content
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @EnvironmentObject var contentRepo: ContentRepository
    @State private var isLoading: Bool = false
    
    var body: some View {
        Button(action: playEpisode) {
            VStack(alignment: .leading, spacing: 6) {
                cover
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(episode.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text("\(Int.random(in: 8...15)) min") // placeholder duration
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
    
    @ViewBuilder private var cover: some View {
        if let urlStr = episode.imageUrl,
           let url = try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: urlStr) {
            CachedAsyncImage(url: url) {
                Rectangle().fill(Color.gray.opacity(0.3))
            }
        } else {
            Rectangle().fill(Color.gray.opacity(0.3))
        }
    }
    
    private func playEpisode() {
        // Prevent multiple simultaneous taps
        guard !isLoading else { return }
        guard !miniPlayerState.isPresentingFullPlayer else { return }
        
        isLoading = true
        
        // Build public URL for audio
        var audioURL: URL? = nil
        if episode.audioUrl.starts(with: "http") {
            audioURL = URL(string: episode.audioUrl)
        } else {
            do {
                audioURL = try SupabaseManager.shared.client.storage.from("audio").getPublicURL(path: episode.audioUrl)
            } catch {
                print("❌ Failed to get audio URL: \(error)")
                isLoading = false
                return
            }
        }
        
        guard let url = audioURL else {
            print("❌ Invalid audio URL for episode: \(episode.title)")
            isLoading = false
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
        isLoading = false
    }
}

// MARK: - Header
private struct HeaderView: View {
    let collection: Collection
    var coverNamespace: Namespace.ID?
    @Environment(\.dismiss) private var dismiss
    @State private var dominant: Color = .black
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let url = getCollectionImageURL(for: collection) {
                    let img = CachedAsyncImage(url: url) { Color.gray.opacity(0.3) }
                    if let ns = coverNamespace {
                        img
                            .matchedGeometryEffect(id: "cover-\(collection.id)", in: ns)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .ignoresSafeArea(edges: .top)
                            .onAppear {
                                // extract dominant color asynchronously
                                DispatchQueue.global(qos: .userInitiated).async {
                                    if let uiImage = UIImage(data: try! Data(contentsOf: url)) {
                                        if let c = ImageColorExtractor.dominantColor(from: uiImage) {
                                            DispatchQueue.main.async { self.dominant = c }
                                        }
                                    }
                                }
                            }
                    } else {
                        img
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .ignoresSafeArea(edges: .top)
                    }
                } else {
                    Color.gray.opacity(0.3)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea(edges: .top)
                }
                
                // Overlay gradient: transitions from transparent, through the extracted dominant color, to solid black at the very bottom for maximum legibility.
                LinearGradient(colors: [.clear, dominant.opacity(0.6), .black], startPoint: .top, endPoint: .bottom)
                    .frame(width: geo.size.width, height: geo.size.height)
                
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(.leading, 16)
                .padding(.top, geo.safeAreaInsets.top + 44)
                
                VStack {
                    Spacer()
                    Text(collection.title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.leading, 24)
                        .padding(.bottom, 32)
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
        GeometryReader { proxy in
            let width = proxy.size.width * cardWidthFactor
            let height = width * 1.45
            TabView(selection: .constant(0)) {
                ForEach(Array(episodes.enumerated()), id: \ .offset) { index, ep in
                    EpisodeCard(episode: ep, cardWidth: width)
                        .frame(width: width, height: height)
                        .tag(index)
                        .padding(.horizontal, (proxy.size.width - width) / 2)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .frame(height: UIScreen.main.bounds.width * cardWidthFactor * 1.45)
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
        VStack(spacing: 12) {
            // Artwork card
            ZStack {
                cover
                    .frame(width: cardWidth, height: cardWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 0.5)
                    )

                // Play icon overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white.opacity(0.85))
            }
            .onTapGesture(perform: play)

            // Title & description centred
            VStack(alignment: .center, spacing: 4) {
                Text(episode.title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                if let desc = episode.description, !desc.isEmpty {
                    Text(desc)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(width: cardWidth * 0.9)
        }
        .frame(width: cardWidth)
    }
    
    // MARK: - Helpers
    @ViewBuilder private var cover: some View {
        if let urlStr = episode.imageUrl,
           let url = try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: urlStr) {
            CachedAsyncImage(url: url) {
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


#Preview("EpisodeCarousel") {
    NavigationStack {
        EpisodeCarousel(episodes: Array(repeating: Content(id: UUID(), title: "Sample Episode", description: "Sample Description", audioUrl: "", imageUrl: nil, createdAt: Date(), transcriptionUrl: nil, collectionId: UUID()), count: 5))
    }
}
