import SwiftUI

struct FileDetailView: View {
    let file: FileItem?

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
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "doc.text",
                description: Text("Select a file to view its properties.")
            )
        }
    }
}
