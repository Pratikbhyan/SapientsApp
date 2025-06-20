import SwiftUI

struct CollectionTileView: View {
    let collection: Collection
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            HStack(spacing: 16) {
                cover
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text(collection.title)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    if let desc = collection.description {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    @ViewBuilder private var cover: some View {
        if let url = getCollectionImageURL(for: collection) {
            CachedAsyncImage(url: url) {
                placeholder
            }
        } else {
            placeholder
        }
    }
    private var placeholder: some View {
        Rectangle().fill(Color.gray.opacity(0.3))
    }
}

struct CollectionsListView: View {
    @StateObject private var repository = CollectionRepository()

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Collections")
        }
        .onAppear {
            Task { await repository.fetchAllCollections() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if repository.isLoading {
            ProgressView("Loading collections…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if repository.collections.isEmpty {
            VStack {
                Image(systemName: "books.vertical")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary.opacity(0.6))
                Text("No collections available")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(repository.collections) { collection in
                        NavigationLink(destination: EpisodesListView(collection: collection)) {
                            CollectionTileView(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

// helper func reuse from earlier
private func getCollectionImageURL(for collection: Collection) -> URL? {
    guard let imgPath = collection.imageUrl else { return nil }
    if imgPath.hasPrefix("collections/") {
        let clean = String(imgPath.dropFirst("collections/".count))
        return try? SupabaseManager.shared.client.storage.from("collections").getPublicURL(path: clean)
    } else {
        return try? SupabaseManager.shared.client.storage.from("images").getPublicURL(path: imgPath)
    }
}

struct CollectionsListView_Previews: PreviewProvider {
    static var previews: some View {
        CollectionsListView()
    }
} 
