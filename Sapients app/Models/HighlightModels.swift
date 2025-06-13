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

// MARK: - Supabase Models

struct SupabaseHighlight: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let contentId: UUID?
    let contentTitle: String
    let highlightText: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentId = "content_id"
        case contentTitle = "content_title"
        case highlightText = "highlight_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID, userId: UUID, contentId: UUID?, contentTitle: String, highlightText: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.contentId = contentId
        self.contentTitle = contentTitle
        self.highlightText = highlightText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Conversion Extensions

extension HighlightSegment {
    init(from supabaseHighlight: SupabaseHighlight) {
        self.id = supabaseHighlight.id
        self.text = supabaseHighlight.highlightText
        self.dateAdded = supabaseHighlight.createdAt
    }
}

extension SupabaseHighlight {
    init(from segment: HighlightSegment, userId: UUID, contentId: UUID?, contentTitle: String) {
        self.id = segment.id
        self.userId = userId
        self.contentId = contentId
        self.contentTitle = contentTitle
        self.highlightText = segment.text
        self.createdAt = segment.dateAdded
        self.updatedAt = segment.dateAdded
    }
}
