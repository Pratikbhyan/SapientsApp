import SwiftUI
import Combine
import UIKit // For UIColor

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: Image?
    
    func load(from url: URL) {
        ImageService.shared.loadImage(from: url) { [weak self] uiImage in
            if let uiImage = uiImage {
                self?.image = Image(uiImage: uiImage)
            } else {
                // Optionally set a default error image or leave as nil
                self?.image = nil 
            }
        }
    }
}

struct CachedAsyncImage<Placeholder: View>: View {
    @StateObject private var loader = ImageLoader()
    private let url: URL?
    private let placeholder: Placeholder

    init(url: URL?, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        content
            .onAppear {
                if let currentUrl = url, loader.image == nil { // Load only if not already loaded and URL exists
                    loader.load(from: currentUrl)
                }
            }
            .onChange(of: url) { oldValue, newValue in
                 if let newUrl = newValue {
                    loader.load(from: newUrl)
                } else {
                    loader.image = nil
                }
            }
    }

    private var content: some View {
        Group {
            if let loadedImage = loader.image {
                loadedImage
                    .resizable()
            } else {
                placeholder
            }
        }
    }
}

struct DefaultPlaceholder: View {
    var body: some View {
        Image(systemName: "photo.fill")
            .resizable()
            .scaledToFit()
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.systemGray5))
    }
}

#if DEBUG
struct CachedAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Image from URL:")
            CachedAsyncImage(url: URL(string: "https://placehold.co/300x200.png")) {
                DefaultPlaceholder()
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 150, height: 100)
            .border(Color.gray)
            
            Text("Placeholder (URL is nil):")
            CachedAsyncImage(url: nil) {
                DefaultPlaceholder()
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 150, height: 100)
            .border(Color.gray)
            
            Text("Placeholder (bad URL leads to nil image):")
            CachedAsyncImage(url: URL(string: "https://thisshouldnotload.xyz/image.png")) {
                DefaultPlaceholder()
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 150, height: 100)
            .border(Color.gray)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
