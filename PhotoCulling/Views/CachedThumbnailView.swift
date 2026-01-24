import SwiftUI

struct CachedThumbnailView: View {
    let url: URL

    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600, maxHeight: 600)
                    .shadow(radius: 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                ContentUnavailableView("Select an Image", systemImage: "photo")
            }
        }
        .task(id: url) {
            isLoading = true
            image = await ThumbnailProvider.shared.thumbnail(for: url, targetSize: 2560)
            isLoading = false
        }
    }
}
