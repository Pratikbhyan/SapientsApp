import SwiftUI
import Combine

// MARK: - View

struct QuickHighlightsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var repo = HighlightRepository.shared
    
    private let skyBlue = Color(red: 135/255.0, green: 206/255.0, blue: 235/255.0)

    var body: some View {
        NavigationView {
            List {
                ForEach(repo.groups) { group in
                    Section(header: GroupHeader(group: group)) {
                        ForEach(group.segments) { seg in
                            Text(seg.text)
                                .padding(.vertical, 4)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        repo.deleteSegment(group: group,
                                                           segment: seg)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Subviews

private struct GroupHeader: View {
    let group: HighlightGroup
    
    var body: some View {
        HStack {
            Spacer()
            Text(group.title)
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Backwards Compatibility Typealias
// This allows existing code that references QuickNotesView to continue working
typealias QuickNotesView = QuickHighlightsView

// MARK: - Preview

struct QuickHighlightsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickHighlightsView()
    }
}
