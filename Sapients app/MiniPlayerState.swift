import SwiftUI
import Combine

/// Lightweight view-model that just converts AudioPlayerService → UI flags
@MainActor
final class MiniPlayerState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var isPresentingFullPlayer: Bool = false
    @Published var keyboardHeight: CGFloat = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init(player: AudioPlayerService) {
        player.$hasLoadedTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasLoadedTrack in
                guard let self = self else { return }
                // Only set visible if we have a track AND we're not presenting full player
                if hasLoadedTrack && !self.isPresentingFullPlayer {
                    self.isVisible = true
                } else if !hasLoadedTrack {
                    self.isVisible = false
                }
            }
            .store(in: &cancellables)
            
        $isPresentingFullPlayer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPresentingFullPlayer in
                guard let self = self else { return }
                if isPresentingFullPlayer {
                    // Always hide mini player when full player is presented
                    self.isVisible = false
                } else if player.hasLoadedTrack {
                    // Show mini player when full player is dismissed and we have a track
                    self.isVisible = true
                }
            }
            .store(in: &cancellables)
    }
}
