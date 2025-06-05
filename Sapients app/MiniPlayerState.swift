import SwiftUI
import Combine

/// Lightweight view-model that just converts AudioPlayerService → UI flags
@MainActor
final class MiniPlayerState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var isPresentingFullPlayer: Bool = false
    
    private var cancellable: AnyCancellable?
    
    init(player: AudioPlayerService) {
        cancellable = player.$hasLoadedTrack
            .assign(to: \.isVisible, on: self)
    }
}
