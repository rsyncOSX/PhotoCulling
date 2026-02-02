import SwiftUI

struct FileDetailView: View {
    @Environment(\.openWindow) var openWindow
    @Bindable var viewModel: SidebarPhotoCullingViewModel
    
    
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
                    
                    HStack {
                        
                        ConditionalGlassButton(
                            systemImage: "document.on.document",
                            text: "Copy tagged",
                            helpText: "Copy tagged images to destination..."
                        ) {
                            viewModel.sheetType = .copytasksview
                            viewModel.showcopytask = true
                        }
                        .disabled(viewModel.selectedSource == nil)
                        
                        ConditionalGlassButton(
                            systemImage: "trash.fill",
                            text: "Clear tagged",
                            helpText: "Clear tagged files"
                        ) {
                            viewModel.alertType = .clearToggledFiles
                            viewModel.showingAlert = true
                        }
                        .disabled(viewModel.creatingthumbnails)
                    }
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
