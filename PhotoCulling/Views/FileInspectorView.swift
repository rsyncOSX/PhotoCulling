import AppKit
import SwiftUI

struct FileInspectorView: View {
    @Binding var file: FileItem?
    @State var nsImage: NSImage?

    var body: some View {
        VStack {
            
            if nsImage != nil {
                // MUST FIX
                HistogramView(nsImage: nsImage!)
                    .padding()
                    
            }
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
                    // nsImage = await ThumbnailProvider.shared.thumbnail(for: file.url, targetSize: 2560)
                }
            }
            
        }
    }
}

/*
 Performance with Large Images: The calculation happens synchronously in the init. If you are processing very high-resolution photos (e.g., 4000x4000+), you might notice a slight UI stutter. If that happens, the fix is to wrap the calculation in a Task or DispatchQueue and use a @State variable to update the view once it's done.
 RGB Channels: Currently, it calculates "Luminance" (brightness), which gives you that nice white/gray curve. If you specifically want separate Red, Green, and Blue lines (like Photoshop's RGB histogram), you would just need three separate arrays in the calculateHistogram function instead of one.
 */
