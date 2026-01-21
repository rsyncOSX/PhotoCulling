import AppKit
import SwiftUI

struct FileInspectorView: View {
    let file: FileItem

    var body: some View {
        Form {
            Section("File Attributes") {
                LabeledContent("Size", value: file.formattedSize)
                LabeledContent("Path", value: file.url.path)
                LabeledContent("Modified", value: file.dateModified.formatted(date: .abbreviated, time: .shortened))
            }
            Section("Quick Actions") {
                Button("Open in Finder") { NSWorkspace.shared.activateFileViewerSelecting([file.url]) }
                Button("Open File") { NSWorkspace.shared.open(file.url) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Details")
    }
}
