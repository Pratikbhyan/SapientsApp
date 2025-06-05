import Foundation

struct NoteSection: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var content: String
}
