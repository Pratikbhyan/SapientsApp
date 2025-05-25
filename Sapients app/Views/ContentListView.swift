import SwiftUI

struct ContentListView: View {
    @StateObject private var repository = ContentRepository()
    
    var body: some View {
        NavigationView {
            Group {
                if repository.isLoading {
                    ProgressView("Loading content...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = repository.error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Error loading content")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await repository.fetchAllContent()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                } else if repository.contents.isEmpty {
                    VStack {
                        Image(systemName: "music.note.list")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No content available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Check back later for new audio content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List(repository.contents) { content in
                        NavigationLink(destination: ContentDetailView(content: content)) {
                            ContentRowView(content: content, repository: repository)
                        }
                    }
                    .refreshable {
                        await repository.fetchAllContent()
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await repository.fetchAllContent()
        }
    }
}

struct ContentRowView: View {
    let content: Content
    let repository: ContentRepository
    
    var body: some View {
        HStack {
            // Thumbnail Image
            if let imageUrl = content.imageUrl,
               let url = repository.getPublicURL(for: imageUrl, bucket: "images") {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
            } else {
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .padding(15)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Content Info
            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.headline)
                    .lineLimit(2)
                
                if let description = content.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                Text(content.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Play indicator
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentListView()
} 
