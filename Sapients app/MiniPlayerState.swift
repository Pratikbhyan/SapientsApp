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
        // Listen to hasLoadedTrack changes
        player.$hasLoadedTrack
            .receive(on: DispatchQueue.main)
            .assign(to: \.isVisible, on: self)
            .store(in: &cancellables)
    }
}
