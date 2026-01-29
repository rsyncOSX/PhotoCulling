import SwiftUI

struct FileDetailView: View {
    @Environment(\.openWindow) var openWindow
    @Binding var cgImage: CGImage?
    @Binding var nsImage: NSImage?

    let files: [FileItem]
    let file: FileItem?
    let selectedFileID: UUID?

    var body: some View {
        if let file = file {
            VStack(spacing: 20) {
                CachedThumbnailView(url: file.url)

                VStack {
                    Text(file.name)
                        .font(.headline)
                    Text(file.url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()
            .frame(minWidth: 300, minHeight: 300)
            .onTapGesture(count: 2) {
                var jpgfileExist = false

                guard let selectedID = selectedFileID,
                      let file = files.first(where: { $0.id == selectedID }) else { return }

                let filejpg = file.url.deletingPathExtension().appendingPathExtension(SupportedFileType.jpg.rawValue)
                if let image = NSImage(contentsOf: filejpg) {
                    nsImage = image
                    jpgfileExist = true
                }

                if jpgfileExist {
                    openWindow(id: WindowIdentifier.zoomnsImage.rawValue)
                } else {
                    Task {
                        let extractor = ExtractEmbeddedPreview()
                        if file.url.pathExtension.lowercased() == SupportedFileType.arw.rawValue {
                            if let mycgImage = await extractor.extractEmbeddedPreview(from: file.url, fullSize: true) {
                                cgImage = mycgImage
                            } else {
                                print("Could not extract preview.")
                            }
                        } else {
                            // nsImage = await ThumbnailProvider.shared.thumbnail(for: file.url, targetSize: 2560)
                        }
                    }

                    openWindow(id: WindowIdentifier.zoomcgImage.rawValue)
                }
            }
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "doc.text",
                description: Text("Select a file to view its properties.")
            )
        }
    }
}
