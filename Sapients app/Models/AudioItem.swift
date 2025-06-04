import Foundation

struct AudioItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let remoteURL: URL
}
