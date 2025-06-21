import SwiftUI
import Combine

/// Simple state manager for mini player visibility and full player presentation
@MainActor
final class MiniPlayerState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var isPresentingFullPlayer: Bool = false
    @Published var keyboardHeight: CGFloat = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init(player: AudioPlayerService) {
        // Show mini player when track is loaded and full player is not shown
        player.$hasLoadedTrack
            .combineLatest($isPresentingFullPlayer)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasTrack, isFullPlayerShown in
                self?.isVisible = hasTrack && !isFullPlayerShown
            }
            .store(in: &cancellables)
    }
    
    /// Present the full player
    func presentFullPlayer() {
        isPresentingFullPlayer = true
    }
    
    /// Dismiss the full player
    func dismissFullPlayer() {
        isPresentingFullPlayer = false
    }
}
