import SwiftUI

struct CachedThumbnailView: View {
    let url: URL

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var isPresentingFullScreen = false

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

                // "View Full Size" button overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresentingFullScreen = true
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }
                }
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                ContentUnavailableView("Select an Image", systemImage: "photo")
            }
        }
        .task(id: url) {
            isLoading = true
            // Fetch high-res for the zoom view
            image = await ThumbnailProvider.shared.thumbnail(for: url, targetSize: 2560)
            isLoading = false
        }
        .sheet(isPresented: $isPresentingFullScreen) {
            ZoomableImageView(nsImage: image)
                .frame(minWidth: 1000, minHeight: 800)
            // Optional: Keep standard title bar for window management,
            // or uncomment .windowStyle(.hiddenTitleBar) for immersion
        }
    }
}
