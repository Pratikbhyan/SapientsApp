import Foundation

// MARK: - Data Models

struct HighlightSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var dateAdded: Date
    var startTime: Float?
    
    init(id: UUID = UUID(), text: String, dateAdded: Date = Date(), startTime: Float? = nil) {
        self.id = id
        self.text = text
        self.dateAdded = dateAdded
        self.startTime = startTime
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
        self.segments = segments.sorted { first, second in
            // If both have start times, sort by start time
            if let firstTime = first.startTime, let secondTime = second.startTime {
                return firstTime < secondTime
            }
            // If only one has start time, prioritize it
            if first.startTime != nil && second.startTime == nil {
                return true
            }
            if first.startTime == nil && second.startTime != nil {
                return false
            }
            // If neither has start time, sort by date added (newest first)
            return first.dateAdded > second.dateAdded
        }
    }
}

// MARK: - Supabase Models

struct SupabaseHighlight: Codable, Identifiable {
    let id: UUID
    let userId: String
    let contentId: UUID?
    let contentTitle: String
    let highlightText: String
    let createdAt: Date
    let updatedAt: Date
    let startTime: Float?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case contentId = "content_id"
        case contentTitle = "content_title"
        case highlightText = "highlight_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case startTime = "start_time"
    }
    
    init(id: UUID, userId: String, contentId: UUID?, contentTitle: String, highlightText: String, createdAt: Date, updatedAt: Date, startTime: Float? = nil) {
        self.id = id
        self.userId = userId
        self.contentId = contentId
        self.contentTitle = contentTitle
        self.highlightText = highlightText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.startTime = startTime
    }
}

// MARK: - Conversion Extensions

extension HighlightSegment {
    init(from supabaseHighlight: SupabaseHighlight) {
        self.id = supabaseHighlight.id
        self.text = supabaseHighlight.highlightText
        self.dateAdded = supabaseHighlight.createdAt
        self.startTime = supabaseHighlight.startTime
    }
}

extension SupabaseHighlight {
    init(from segment: HighlightSegment, userId: String, contentId: UUID?, contentTitle: String) {
        self.id = segment.id
        self.userId = userId
        self.contentId = contentId
        self.contentTitle = contentTitle
        self.highlightText = segment.text
        self.createdAt = segment.dateAdded
        self.updatedAt = segment.dateAdded
        self.startTime = segment.startTime
    }
}
