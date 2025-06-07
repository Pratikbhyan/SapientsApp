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
        setupRemoteTransportControls()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
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
        
        // Optional: Add skip forward/backward commands if needed
        // commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)] // Example: 15 seconds
        // commandCenter.skipForwardCommand.addTarget { /* ... */ }
        // commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        // commandCenter.skipBackwardCommand.addTarget { /* ... */ }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentContent?.title ?? "Sapients Audio"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Sapients" 
        
        if let imageURLString = currentContent?.imageUrl, let imageURL = URL(string: imageURLString) {
            // Asynchronously load image and update artwork. This part might need a proper image caching/loading mechanism.
            // For simplicity, this is a basic URLSession task. Consider using your ImageService or Kingfisher if applicable.
            URLSession.shared.dataTask(with: imageURL) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async { // Ensure UI updates on main thread
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] = artwork
                    }
                }
            }.resume()
        } else {
            // You could set a placeholder artwork if no specific image is available
            // For example, using an app icon image.
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? currentPlaybackRate // Use player's actual rate if available

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
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
        self.hasLoadedTrack = true
        
        if let currentItem = playerItem {
            Task {
                do {
                    let loadedDuration = try await currentItem.asset.load(.duration)
                    DispatchQueue.main.async {
                        self.duration = CMTimeGetSeconds(loadedDuration)
                        self.updateNowPlayingInfo() // Update after duration is known
                    }
                } catch {
                    print("Failed to load duration: \(error)")
                    DispatchQueue.main.async {
                        self.duration = 0
                        self.updateNowPlayingInfo() // Update even if duration fails
                    }
                }
            }
        } else {
            self.duration = 0
            self.updateNowPlayingInfo() // Update if no item
        }
        
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.currentTime = CMTimeGetSeconds(time)
                // Update now playing info periodically for progress
                if strongSelf.isPlaying { // Only update if playing to avoid unnecessary updates
                   strongSelf.updateNowPlayingInfo()
                }
            }
        }
        
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: CMTime.zero)
                self.updateNowPlayingInfo() // Update on end
            }
            .store(in: &cancellables)
            
        // Initial update of Now Playing Info when track is loaded
        updateNowPlayingInfo()
    }
    
    // MARK: - Playback Controls
    func play() {
        do { 
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session for play: \(error)")
        }
        player?.play()
        player?.rate = self.currentPlaybackRate 
        isPlaying = true
        updateNowPlayingInfo() 
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo() 
        // Optional: Deactivate audio session after a delay if desired for power saving, but often not needed.
        // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        //     if !self.isPlaying {
        //         do {
        //             try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        //         } catch {
        //             print("Failed to deactivate audio session: \(error)")
        //         }
        //     }
        // }
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
        // updateNowPlayingInfo() is called by play() and pause()
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        self.currentContent = nil 
        self.hasLoadedTrack = false
        
        // Deactivate audio session
        // #if os(iOS) 
        // do {
        //     try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // } catch {
        //     print("Failed to deactivate audio session on stop: \(error)")
        // }
        // #endif
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
