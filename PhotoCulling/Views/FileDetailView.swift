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
                    Text(file.url.deletingLastPathComponent().path())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .padding()
            .frame(minWidth: 300, minHeight: 300)
            .onTapGesture(count: 2) {
                guard let selectedID = selectedFileID,
                      let file = files.first(where: { $0.id == selectedID }) else { return }

                JPGPreviewHandler.handle(
                    file: file,
                    setNSImage: { nsImage = $0 },
                    setCGImage: { cgImage = $0 },
                    openWindow: { id in openWindow(id: id) }
                )
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

/*
 nsImage = await ThumbnailProvider.shared.thumbnail(for: file.url, targetSize: 2560)
 */
