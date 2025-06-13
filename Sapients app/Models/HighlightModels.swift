import Foundation

// MARK: - Data Models

struct HighlightSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var dateAdded: Date
    
    init(id: UUID = UUID(), text: String, dateAdded: Date = Date()) {
        self.id = id
        self.text = text
        self.dateAdded = dateAdded
    }
}

struct HighlightGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var thumbnailName: String?
    var segments: [HighlightSegment]
    
    init(id: UUID = UUID(),
         title: String,
         thumbnailName: String? = nil,
         segments: [HighlightSegment] = []) {
        self.id = id
        self.title = title
        self.thumbnailName = thumbnailName
        self.segments = segments
    }
}