import AppKit
import SwiftUI

struct FileInspectorView: View {
    @Binding var file: FileItem?
    @State var nsImage: NSImage?

    var body: some View {
        VStack {
            HistogramView(nsImage: $nsImage)
                .padding()

            if let file {
                Form {
                    Section("File Attributes") {
                        LabeledContent("Size", value: file.formattedSize)
                        LabeledContent("Path", value: file.url.path)
                        LabeledContent("Modified", value: file.dateModified.formatted(date: .abbreviated, time: .shortened))
                    }
                    Section("Quick Actions") {
                        Button("Open in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                        Button("Open ARW File") { NSWorkspace.shared.open(file.url) }
                    }
                }
                .formStyle(.grouped)
                .navigationTitle("Details")
            }
        }
        .onChange(of: file) {
            Task {
                if let file {
                    nsImage = await ThumbnailProvider.shared.thumbnail(for: file.url, targetSize: 1024)
                }
            }
        }
    }
}
