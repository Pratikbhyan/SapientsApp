import SwiftUI

struct JumpBackInView: View {
    let content: Content
    let action: () -> Void
    
    @EnvironmentObject private var repo: ContentRepository
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let img = content.imageUrl, let url = repo.getPublicURL(for: img, bucket: "images") {
                    CachedAsyncImage(url: url) { Color.gray }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "arrowtriangle.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
} 