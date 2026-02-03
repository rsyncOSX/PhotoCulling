//
//  extension+SidebarPhotoCullingView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 21/01/2026.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Type to handle JPG/preview extraction and window opening
enum JPGPreviewHandler {
    static func handle(
        file: FileItem,
        setNSImage: @escaping (NSImage?) -> Void,
        setCGImage: @escaping (CGImage?) -> Void,
        openWindow: @escaping (String) -> Void
    ) {
        let filejpg = file.url.deletingPathExtension().appendingPathExtension(SupportedFileType.jpg.rawValue)
        if let image = NSImage(contentsOf: filejpg) {
            setNSImage(image)
            // The jpgs are already created, open view shows the photo immidiate
            openWindow(WindowIdentifier.zoomnsImage.rawValue)
        } else {
            Task {
                setCGImage(nil)
                // Open the view here to indicate process of extracting the cgImage
                openWindow(WindowIdentifier.zoomcgImage.rawValue)
                let extractor = ExtractEmbeddedPreview()
                if file.url.pathExtension.lowercased() == SupportedFileType.arw.rawValue {
                    if let mycgImage = await extractor.extractEmbeddedPreview(from: file.url, fullSize: true) {
                        setCGImage(mycgImage)
                    }
                }
            }
        }
    }
}

extension SidebarPhotoCullingView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "square.3.layers.3d.down.forward",
                text: "",
                helpText: "Extract JPG images from ARW files..."
            ) {
                guard viewModel.selectedSource != nil else { return }
                viewModel.alertType = .extractJPGs
                viewModel.showingAlert = true
            }
            .disabled(viewModel.creatingthumbnails)
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "arrow.up.trash",
                text: "",
                helpText: "Reset memory and disk cache"
            ) {
                viewModel.alertType = .clearMemoryandThumbnails
                viewModel.showingAlert = true
            }
            .disabled(viewModel.creatingthumbnails)
        }

        ToolbarItem { Spacer() }
    }

    // File table

    var filetableview: some View {
        VStack(alignment: .leading) {
            Table(viewModel.filteredFiles.compactMap { file in
                (viewModel.getRating(for: file) >= viewModel.rating) ? file : nil
            },
            selection: $viewModel.selectedFileID,
            sortOrder: $viewModel.sortOrder) {
                TableColumn("", value: \.id) { file in
                    Button(action: {
                        handleToggleSelection(for: file)
                    }, label: {
                        Image(systemName: marktoggle(for: file) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(.blue)
                    })
                    .buttonStyle(.plain)
                }
                .width(30)
                TableColumn("Rating") { file in
                    RatingView(
                        rating: viewModel.getRating(for: file),
                        onChange: { newRating in
                            // If not toggled, toggle it on first
                            if !marktoggle(for: file) {
                                handleToggleSelection(for: file)
                            }
                            viewModel.updateRating(for: file, rating: newRating)
                        }
                    )
                }
                .width(CGFloat(ThumbnailSize.grid))
                TableColumn("Name", value: \.name)
                TableColumn("Size", value: \.size) { file in
                    Text(file.formattedSize).monospacedDigit()
                }
                .width(75)
                TableColumn("Type", value: \.type)
                    .width(140)
                TableColumn("Modified", value: \.dateModified) { file in
                    Text(file.dateModified, style: .date)
                }
            }

            if showPhotoGridView() {
                PhotoGridView(
                    cullingmanager: viewModel.cullingmanager,
                    files: viewModel.filteredFiles,
                    photoURL: viewModel.selectedSource?.url,
                    onPhotoSelected: { file in
                        viewModel.selectedFileID = file.id
                        viewModel.selectedFile = file
                        viewModel.isInspectorPresented = true
                    }
                )
            }
        }
        .onChange(of: viewModel.selectedFileID) {
            if let index = viewModel.files.firstIndex(where: { $0.id == viewModel.selectedFileID }) {
                viewModel.selectedFileID = viewModel.files[index].id
                viewModel.selectedFile = viewModel.files[index]
                viewModel.isInspectorPresented = true
            } else {
                viewModel.isInspectorPresented = false
            }
        }
        .onChange(of: viewModel.focusnavigateUp) {
            if viewModel.focusnavigateUp {
                navigateToAdjacentFile(direction: .previous)
                viewModel.focusnavigateUp = false
            }
        }
        .onChange(of: viewModel.focusnavigateDown) {
            if viewModel.focusnavigateDown {
                navigateToAdjacentFile(direction: .next)
                viewModel.focusnavigateDown = false
            }
        }
        .onChange(of: viewModel.focusPressEnter) {
            if viewModel.focusPressEnter {
                applyPendingUpdatesAndFocus()
                viewModel.focusPressEnter = false
            }
        }
        .contextMenu(forSelectionType: FileItem.ID.self) { _ in
        } primaryAction: { _ in
            guard let selectedID = viewModel.selectedFileID,
                  let file = viewModel.files.first(where: { $0.id == selectedID }) else { return }

            JPGPreviewHandler.handle(
                file: file,
                setNSImage: { nsImage = $0 },
                setCGImage: { cgImage = $0 },
                openWindow: { id in openWindow(id: id) }
            )
        }
        .onKeyPress(.space) {
            guard let selectedID = viewModel.selectedFileID,
                  let file = viewModel.files.first(where: { $0.id == selectedID }) else { return .handled }

            JPGPreviewHandler.handle(
                file: file,
                setNSImage: { nsImage = $0 },
                setCGImage: { cgImage = $0 },
                openWindow: { id in openWindow(id: id) }
            )
            return .handled
        }
    }

    // MARK: - Navigation Helper

    enum NavigationDirection {
        case previous
        case next
    }

    func navigateToAdjacentFile(direction: NavigationDirection) {
        let filteredAndRated = viewModel.filteredFiles.compactMap { file in
            (viewModel.getRating(for: file) >= viewModel.rating) ? file : nil
        }

        guard !filteredAndRated.isEmpty else { return }

        var selectedFile: FileItem?

        if let currentID = viewModel.selectedFileID,
           let currentIndex = filteredAndRated.firstIndex(where: { $0.id == currentID }) {
            let newIndex: Int
            if direction == .previous {
                newIndex = max(0, currentIndex - 1)
            } else {
                newIndex = min(filteredAndRated.count - 1, currentIndex + 1)
            }
            viewModel.selectedFileID = filteredAndRated[newIndex].id
            viewModel.selectedFile = filteredAndRated[newIndex]
            selectedFile = filteredAndRated[newIndex]
            viewModel.isInspectorPresented = true
        } else {
            // If no selection, select the first file
            viewModel.selectedFileID = filteredAndRated.first?.id
            viewModel.selectedFile = filteredAndRated.first
            selectedFile = filteredAndRated.first
            viewModel.isInspectorPresented = true
        }

        // Update zoom windows based on their focus state
        if let file = selectedFile {
            if zoomCGImageWindowFocused || zoomNSImageWindowFocused {
                // Window is in focus, update immediately
                JPGPreviewHandler.handle(
                    file: file,
                    setNSImage: { nsImage = $0 },
                    setCGImage: { cgImage = $0 },
                    openWindow: { id in openWindow(id: id) }
                )
            } else {
                // Window is in background, defer update until Enter is pressed
                viewModel.pendingCGImageUpdate = nil
                viewModel.pendingNSImageUpdate = nil
                JPGPreviewHandler.handle(
                    file: file,
                    setNSImage: { viewModel.pendingNSImageUpdate = $0 },
                    setCGImage: { viewModel.pendingCGImageUpdate = $0 },
                    openWindow: { id in openWindow(id: id) }
                )
            }
        }
    }
    
    func applyPendingUpdatesAndFocus() {
        if let cgImage = viewModel.pendingCGImageUpdate {
            self.cgImage = cgImage
            zoomCGImageWindowFocused = true
        }
        
        if let nsImage = viewModel.pendingNSImageUpdate {
            self.nsImage = nsImage
            zoomNSImageWindowFocused = true
        }
        
        // Clear pending updates
        viewModel.pendingCGImageUpdate = nil
        viewModel.pendingNSImageUpdate = nil
    }

    // MARK: - Helper Functions

    func marktoggle(for file: FileItem) -> Bool {
        if let index = viewModel.cullingmanager.savedFiles.firstIndex(where: { $0.catalog == viewModel.selectedSource?.url }),
           let filerecords = viewModel.cullingmanager.savedFiles[index].filerecords {
            return filerecords.contains { $0.fileName == file.name }
        }
        return false
    }

    func showPhotoGridView() -> Bool {
        guard let catalogURL = viewModel.selectedSource?.url,
              let index = viewModel.cullingmanager.savedFiles.firstIndex(where: { $0.catalog == catalogURL })
        else {
            return false
        }
        // Show the grid when there are filerecords and the collection is not empty
        if let records = viewModel.cullingmanager.savedFiles[index].filerecords {
            return !records.isEmpty
        }
        return false
    }

    func handleToggleSelection(for file: FileItem) {
        viewModel.cullingmanager.toggleSelectionSavedFiles(
            in: file.url,
            toggledfilename: file.name
        )
    }

    func handlePickerResult(_ result: Result<URL, Error>) {
        if case let .success(url) = result {
            // Security: Request persistent access
            if url.startAccessingSecurityScopedResource() {
                let source = FolderSource(name: url.lastPathComponent, url: url)
                viewModel.sources.append(source)
                viewModel.selectedSource = source
            }
        }
    }

    func extractAllJPGS() {
        Task {
            viewModel.creatingthumbnails = true

            let handlers = CreateFileHandlers().createFileHandlers(
                fileHandler: viewModel.fileHandler,
                maxfilesHandler: viewModel.maxfilesHandler
            )

            let extract = ExtractAndSaveJPGs()
            await extract.setFileHandlers(handlers)
            guard let url = viewModel.selectedSource?.url else { return }
            await extract.extractAndSaveAlljpgs(from: url, fullSize: false)

            viewModel.creatingthumbnails = false
        }
    }
}
