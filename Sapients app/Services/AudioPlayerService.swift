import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentTranscriptionIndex: Int = 0
    @Published var currentPlaybackRate: Float = 1.0
    @Published var hasLoadedTrack: Bool = false
    @Published var currentContent: Content? = nil
    private(set) var currentLoadedURL: URL?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        #endif
    }
    
    // MARK: - Audio Loading
    func loadAudio(from url: URL, for content: Content) {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // Reset state for new audio
        self.isPlaying = false
        self.currentTime = 0
        self.duration = 0
        self.currentTranscriptionIndex = 0
        self.currentLoadedURL = nil
        self.currentContent = nil
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        self.currentLoadedURL = url
        self.currentContent = content
        self.hasLoadedTrack = true // Set this to true when audio is loaded
        
        // Get duration asynchronously
        if let currentItem = playerItem {
            Task {
                do {
                    let loadedDuration = try await currentItem.asset.load(.duration)
                    DispatchQueue.main.async {
                        self.duration = CMTimeGetSeconds(loadedDuration)
                    }
                } catch {
                    print("Failed to load duration: \(error)")
                    DispatchQueue.main.async {
                        self.duration = 0
                    }
                }
            }
        } else {
            self.duration = 0
        }
        
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.currentTime = CMTimeGetSeconds(time)
            }
        }
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: CMTime.zero)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playback Controls
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
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
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
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
        self.hasLoadedTrack = false // Set this to false when stopping
    }

    // MARK: - Transcription Sync
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
    
    // MARK: - Cleanup
    deinit {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        cancellables.forEach { $0.cancel() }
    }
}
