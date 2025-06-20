import SwiftUI
import Supabase

struct EpisodesListView: View {
    let collection: Collection
    
    @State private var episodes: [Content] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Shared services from app environment
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @EnvironmentObject var contentRepo: ContentRepository
    
    private let supabase = SupabaseManager.shared.client
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(collection: collection)
                .frame(height: UIScreen.main.bounds.height * 0.30)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        guard !isLoading else { return }
        isLoading = true
        // Build public URL for audio
        var audioURL: URL? = nil
        if episode.audioUrl.starts(with: "http") {
            audioURL = URL(string: episode.audioUrl)
        } else {
            audioURL = try? SupabaseManager.shared.client.storage.from("audio").getPublicURL(path: episode.audioUrl)
        }
        if let url = audioURL {
            audioPlayer.loadAudio(from: url, for: episode, autoPlay: true)
            miniPlayerState.isVisible = true
            // fetch transcriptions in background
            Task {
                await contentRepo.fetchTranscriptions(for: episode.id, from: episode.transcriptionUrl)
            }
        }
        isLoading = false
    }
}

// MARK: - Header
private struct HeaderView: View {
    let collection: Collection
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let url = getCollectionImageURL(for: collection) {
                    CachedAsyncImage(url: url) {
                        Color.gray.opacity(0.3)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea(edges: .top)
                } else {
                    Color.gray.opacity(0.3)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .ignoresSafeArea(edges: .top)
                }
                
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
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
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.68
            let spacing: CGFloat = 16
            let sidePadding = (proxy.size.width - width) / 2
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(episodes) { episode in
                        EpisodeCard(episode: episode, cardWidth: width)
                    }
                }
                .padding(.horizontal, sidePadding)
            }
        }
        .frame(height: 240)
    }
}

private struct EpisodeCard: View {
    let episode: Content
    let cardWidth: CGFloat
    @EnvironmentObject var audioPlayer: AudioPlayerService
    @EnvironmentObject var miniPlayerState: MiniPlayerState
    @EnvironmentObject var contentRepo: ContentRepository
    
    var body: some View {
        GeometryReader { geo in
            let mid = geo.frame(in: .global).midX
            let screenMid = UIScreen.main.bounds.width / 2
            let scale = max(0.8, 1 - abs(screenMid - mid) / 600)
            Button(action: play) {
                ZStack(alignment: .bottomTrailing) {
                    cover
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                        .padding(12)
                }
                .frame(width: cardWidth, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .scaleEffect(scale)
            }
            .buttonStyle(.plain)
        }
        .frame(width: cardWidth, height: 200)
    }
    @ViewBuilder private var cover: some View {
        if let urlStr = episode.imageUrl,
           let url = try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: urlStr) {
            CachedAsyncImage(url: url) { Color.gray.opacity(0.3) }
                .aspectRatio(contentMode: .fill)
        } else {
            Color.gray.opacity(0.3)
        }
    }
    private func play() {
        var audioURL: URL? = nil
        if episode.audioUrl.starts(with: "http") {
            audioURL = URL(string: episode.audioUrl)
        } else {
            audioURL = try? SupabaseManager.shared.client.storage.from("audio").getPublicURL(path: episode.audioUrl)
        }
        if let url = audioURL {
            audioPlayer.loadAudio(from: url, for: episode, autoPlay: true)
            miniPlayerState.isVisible = true
            Task { await contentRepo.fetchTranscriptions(for: episode.id, from: episode.transcriptionUrl) }
        }
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
