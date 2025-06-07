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
    
    private var currentArtwork: MPMediaItemArtwork?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
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
    
    func loadAudio(from url: URL, for content: Content) {
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        self.isPlaying = false
        self.currentTime = 0
        self.duration = 0
        self.currentTranscriptionIndex = 0
        self.currentLoadedURL = nil
        self.currentContent = nil
        self.currentArtwork = nil
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        self.currentLoadedURL = url
        self.currentContent = content
        self.hasLoadedTrack = true
        
        loadArtworkOnce()
        
        if let currentItem = playerItem {
            Task {
                do {
                    let loadedDuration = try await currentItem.asset.load(.duration)
                    DispatchQueue.main.async {
                        self.duration = CMTimeGetSeconds(loadedDuration)
                        self.updateNowPlayingInfo()
                    }
                } catch {
                    print("Failed to load duration: \(error)")
                    DispatchQueue.main.async {
                        self.duration = 0
                        self.updateNowPlayingInfo()
                    }
                }
            }
        } else {
            self.duration = 0
            self.updateNowPlayingInfo()
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
    }
    
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
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
}
