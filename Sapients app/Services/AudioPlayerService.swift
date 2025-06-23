import Foundation
import AVFoundation
import Combine
import MediaPlayer

@MainActor
class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    private let cacheManager = AudioCacheManager.shared
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentTranscriptionIndex: Int = 0
    @Published var currentPlaybackRate: Float = 1.0
    @Published var hasLoadedTrack: Bool = false
    @Published var currentContent: Content? = nil
    @Published var isLoadingAudio: Bool = false
    @Published var isBuffering: Bool = false
    private(set) var currentLoadedURL: URL?
    
    private var currentArtwork: MPMediaItemArtwork?
    
    private var cancellables = Set<AnyCancellable>()
    
    private var lastPersist: Date = Date()
    private let persistInterval: TimeInterval = 5 // seconds
    
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    /// Configure an initial, non-intrusive audio session that allows other audio (e.g. Music app) to continue playing
    /// when the user merely opens the Sapients app without starting playback.
    ///
    /// We set the category to `.ambient` with the `.mixWithOthers` option and **do not** activate the session yet.
    /// When the user actually starts playback (`play()`), we will promote the session to `.playback` and activate it.
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            // Intentionally NOT calling setActive(true) here to avoid interrupting other audio.
        } catch {
            print("Failed to set up passive audio session: \(error)")
        }
        #endif
    }

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if !self.isPlaying {
                self.play()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.isPlaying {
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.togglePlayPause()
            return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)] 
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.seek(to: self.currentTime + 15)
            return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.seek(to: self.currentTime - 15)
            return .success
        }
    }

    private func loadArtworkOnce() {
        currentArtwork = nil
        
        if let imageUrlString = currentContent?.imageUrl,
           let imageURL = ContentRepository().getPublicURL(for: imageUrlString, bucket: "images") {
            ImageService.shared.loadImage(from: imageURL) { [weak self] uiImage in
                DispatchQueue.main.async {
                    if let image = uiImage {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        self?.currentArtwork = artwork
                        self?.updateNowPlayingInfoWithCurrentArtwork()
                    }
                }
            }
        }
    }

    private func updateNowPlayingInfo() {
        updateNowPlayingInfoWithCurrentArtwork()
    }
    
    private func updateNowPlayingInfoWithCurrentArtwork() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentContent?.title ?? "Sapients Audio"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Sapients" 
        
        if let artwork = currentArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? currentPlaybackRate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func loadAudio(from urlString: String, for content: Content, autoPlay: Bool = false) {
        guard let remoteURL = URL(string: urlString) else {
            print("❌ Invalid audio URL: \(urlString)")
            return
        }
        
        loadAudio(from: remoteURL, for: content, autoPlay: autoPlay)
    }
    
    func loadAudio(from remoteURL: URL, for content: Content, autoPlay: Bool = false) {
        // Prevent loading if already loading the same content
        if isLoadingAudio && currentContent?.id == content.id {
            print("ℹ️ Already loading audio for: \(content.title)")
            return
        }
        
        // Stop current audio immediately to prevent overlap
        if let player = player {
            player.pause()
            self.isPlaying = false
        }
        
        // Clean up previous audio
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Set buffering state immediately
        self.isBuffering = true
        self.isPlaying = false
        self.isLoadingAudio = true
        self.currentTime = 0
        self.duration = 0
        self.currentTranscriptionIndex = 0
        self.currentLoadedURL = nil
        self.currentContent = content
        self.currentArtwork = nil
        
        print("🎵 Loading audio for: \(content.title)")
        
        // Use cache manager with content info for subscription-aware caching
        cacheManager.getAudioURL(for: remoteURL, content: content, priority: .high) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Double-check we're still loading the same content
                guard self.currentContent?.id == content.id else {
                    print("ℹ️ Content changed during loading, ignoring result")
                    return
                }
                
                switch result {
                case .success(let audioURL):
                    self.setupAudioPlayer(with: audioURL, content: content, autoPlay: autoPlay)
                case .failure(let error):
                    print("❌ Failed to load audio: \(error.localizedDescription)")
                    self.handleLoadingError()
                    // Fallback to direct URL if cache fails
                    self.setupAudioPlayer(with: remoteURL, content: content, autoPlay: autoPlay)
                }
            }
        }
    }
    
    private func handleLoadingError() {
        self.isLoadingAudio = false
        self.isBuffering = false
        // Don't clear hasLoadedTrack or currentContent to maintain UI state
        // Just clear the loading states
    }
    
    private func setupAudioPlayer(with url: URL, content: Content, autoPlay: Bool = false) {
        // Clean up any existing player first
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        self.currentLoadedURL = url
        self.currentContent = content
        self.hasLoadedTrack = true
        self.isLoadingAudio = false
        // Clear buffering state when player is ready
        self.isBuffering = false
        
        loadArtworkOnce()
        
        print("✅ Audio player setup complete for: \(content.title)")
        
        if let currentItem = playerItem {
            Task {
                do {
                    let loadedDuration = try await currentItem.asset.load(.duration)
                    DispatchQueue.main.async {
                        self.duration = CMTimeGetSeconds(loadedDuration)
                        self.updateNowPlayingInfo()
                        
                        // Auto-play if requested
                        if autoPlay {
                            self.play()
                        }
                    }
                } catch {
                    print("Failed to load duration: \(error)")
                    DispatchQueue.main.async {
                        self.duration = 0
                        self.updateNowPlayingInfo()
                        
                        // Auto-play if requested, even if duration loading failed
                        if autoPlay {
                            self.play()
                        }
                    }
                }
            }
        } else {
            self.duration = 0
            self.updateNowPlayingInfo()
            
            // Auto-play if requested
            if autoPlay {
                self.play()
            }
        }
        
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.currentTime = CMTimeGetSeconds(time)
                if strongSelf.isPlaying {
                   strongSelf.updateNowPlayingInfo()
                   strongSelf.persistProgress()
                }
            }
        }
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: CMTime.zero)
                self.updateNowPlayingInfo()
            }
            .store(in: &cancellables)
            
        updateNowPlayingInfo()
        
        print("✅ Audio player setup complete for: \(content.title)")
    }
    
    func preloadUpcomingContent(_ contents: [Content]) {
        print("ℹ️ Preemptive caching disabled - episodes cached only when user plays them")
    }

    func play() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Elevate the session to playback and activate it so our audio gets priority once the user presses play.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to activate audio session for play: \(error)")
        }
        #endif
        player?.play()
        player?.rate = self.currentPlaybackRate
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        persistProgress()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func setPlaybackRate(to rate: Float) {
        guard let player = player else { return }
        player.rate = rate
        self.currentPlaybackRate = rate
        if rate == 0.0 {
            if self.isPlaying {
                self.isPlaying = false
            }
        } else {
            if !self.isPlaying {
                if let currentItem = player.currentItem, currentItem.currentTime() >= currentItem.duration {
                    player.seek(to: .zero)
                    self.currentTime = 0
                }
                self.isPlaying = true
            }
        }
        self.updateNowPlayingInfo()
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        self.currentTime = time
        updateNowPlayingInfo()
    }
    
    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        if let timeObserver = self.timeObserver {
        }
        timeObserver = nil
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        self.isPlaying = false
        self.currentTime = 0
        self.duration = 0
        self.currentTranscriptionIndex = 0
        self.currentLoadedURL = nil
        self.currentContent = nil
        self.hasLoadedTrack = false
        self.currentArtwork = nil
        // Clear buffering state when stopping
        self.isBuffering = false
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        persistProgress()
    }

    func updateCurrentTranscription(transcriptions: [Transcription]) {
        for (index, transcription) in transcriptions.enumerated() {
            if currentTime >= TimeInterval(transcription.startTime) && 
               currentTime <= TimeInterval(transcription.endTime) {
                if currentTranscriptionIndex != index {
                    currentTranscriptionIndex = index
                }
                break
            }
        }
    }
    
    deinit {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        cancellables.forEach { $0.cancel() }
    }
    
    private func persistProgress() {
        guard let content = currentContent else { return }
        let now = Date()
        if now.timeIntervalSince(lastPersist) < persistInterval { return }
        lastPersist = now
        if let data = try? JSONEncoder().encode(content) {
            UserDefaults.standard.set(data, forKey: "lastEpisodeContent")
        }
        UserDefaults.standard.set(currentTime, forKey: "lastEpisodePosition")
    }
    
    static func loadSavedProgress() -> (Content, Double)? {
        if let data = UserDefaults.standard.data(forKey: "lastEpisodeContent"),
           let content = try? JSONDecoder().decode(Content.self, from: data) {
            let pos = UserDefaults.standard.double(forKey: "lastEpisodePosition")
            return (content, pos)
        }
        return nil
    }
}
