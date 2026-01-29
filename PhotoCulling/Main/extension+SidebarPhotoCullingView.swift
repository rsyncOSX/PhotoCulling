//
//  extension+SidebarPhotoCullingView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 21/01/2026.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Free function to handle JPG/preview extraction and window opening
func handleJPGorPreview(
    file: FileItem,
    setNSImage: @escaping (NSImage?) -> Void,
    setCGImage: @escaping (CGImage?) -> Void,
    openWindow: @escaping (String) -> Void
) {
    let filejpg = file.url.deletingPathExtension().appendingPathExtension(SupportedFileType.jpg.rawValue)
    if let image = NSImage(contentsOf: filejpg) {
        setNSImage(image)
        openWindow(WindowIdentifier.zoomnsImage.rawValue)
    } else {
        Task {
            setCGImage(nil)
            let extractor = ExtractEmbeddedPreview()
            if file.url.pathExtension.lowercased() == SupportedFileType.arw.rawValue {
                if let mycgImage = await extractor.extractEmbeddedPreview(from: file.url, fullSize: true) {
                    setCGImage(mycgImage)
                }
            }
            openWindow(WindowIdentifier.zoomcgImage.rawValue)
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
                guard selectedSource != nil else { return }
                showingAlert = true
            }
            .disabled(creatingthumbnails)
        }

        ToolbarItem {
            Spacer()
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "plus.magnifyingglass",
                text: "",
                helpText: "Extract JPG from selected ARW file..."
            ) {
                guard let selectedID = selectedFileID,
                      let file = files.first(where: { $0.id == selectedID }) else { return }

                Task {
                    let extractor = ExtractEmbeddedPreview()
                    if file.url.pathExtension.lowercased() == "arw" {
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
            .disabled(creatingthumbnails)
        }

        ToolbarItem {
            Spacer()
        }

        // Only show toolbar items when this tab is active
        if !files.isEmpty {
            ToolbarItem {
                Text("\(filteredFiles.count) ARW files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "trash.fill",
                text: "",
                helpText: "Clear toggled files"
            ) {
                if let url = selectedSource?.url {
                    cullingmanager.resetSavedFiles(in: url)
                }
            }
            .disabled(creatingthumbnails)
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "arrow.up.trash",
                text: "",
                helpText: "Reset memory and disk cache"
            ) {
                Task {
                    await ThumbnailProvider.shared.clearCaches()
                    sources.removeAll()
                    selectedSource = nil
                    filteredFiles.removeAll()
                    files.removeAll()
                    selectedFile = nil
                }
            }
            .disabled(creatingthumbnails)
        }

        ToolbarItem {
            Spacer()
        }
    }

    // File table

    var filetableview: some View {
        VStack(alignment: .leading) {
            Table(filteredFiles, selection: $selectedFileID, sortOrder: $sortOrder) {
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
                        rating: getRating(for: file),
                        onChange: { newRating in
                            // If not toggled, toggle it on first
                            if !marktoggle(for: file) {
                                handleToggleSelection(for: file)
                            }
                            updateRating(for: file, rating: newRating)
                        }
                    )
                }
                .width(100)
                TableColumn("Name", value: \.name)
                TableColumn("Size", value: \.size) { file in
                    Text(file.formattedSize).monospacedDigit()
                }
                TableColumn("Type", value: \.type)
                TableColumn("Modified", value: \.dateModified) { file in
                    Text(file.dateModified, style: .date)
                }
            }

            if showPhotoGridView() {
                PhotoGridView(
                    cullingmanager: cullingmanager,
                    files: filteredFiles,
                    photoURL: selectedSource?.url
                )
            }
        }
        .onChange(of: selectedFileID) {
            if let index = files.firstIndex(where: { $0.id == selectedFileID }) {
                selectedFileID = files[index].id
                selectedFile = files[index]
                isInspectorPresented = true
            } else {
                isInspectorPresented = false
            }
        }
        .contextMenu(forSelectionType: FileItem.ID.self) { _ in
        } primaryAction: { _ in
            guard let selectedID = selectedFileID,
                  let file = files.first(where: { $0.id == selectedID }) else { return }
            handleJPGorPreview(
                file: file,
                setNSImage: { nsImage = $0 },
                setCGImage: { cgImage = $0 },
                openWindow: { id in openWindow(id: id) }
            )
        }
        .onKeyPress(.space) {
            guard let selectedID = selectedFileID,
                  let file = files.first(where: { $0.id == selectedID }) else { return .handled }
            handleJPGorPreview(
                file: file,
                setNSImage: { nsImage = $0 },
                setCGImage: { cgImage = $0 },
                openWindow: { id in openWindow(id: id) }
            )
            return .handled
        }
    }

    // MARK: - Helper Functions

    func marktoggle(for file: FileItem) -> Bool {
        if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == selectedSource?.url }),
           let filerecords = cullingmanager.savedFiles[index].filerecords {
            return filerecords.contains { $0.fileName == file.name }
        }
        return false
    }

    func showPhotoGridView() -> Bool {
        guard let catalogURL = selectedSource?.url,
              let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == catalogURL })
        else {
            return false
        }
        // Show the grid when there are filerecords and the collection is not empty
        if let records = cullingmanager.savedFiles[index].filerecords {
            return !records.isEmpty
        }
        return false
    }

    func handleToggleSelection(for file: FileItem) {
        cullingmanager.toggleSelectionSavedFiles(
            in: file.url,
            toggledfilename: file.name
        )
    }

    func getRating(for file: FileItem) -> Int {
        if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == selectedSource?.url }),
           let filerecords = cullingmanager.savedFiles[index].filerecords,
           let record = filerecords.first(where: { $0.fileName == file.name }) {
            return record.rating ?? 0
        }
        return 0
    }

    func updateRating(for file: FileItem, rating: Int) {
        guard let selectedSource = selectedSource else { return }
        if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == selectedSource.url }),
           let recordIndex = cullingmanager.savedFiles[index].filerecords?.firstIndex(where: { $0.fileName == file.name }) {
            cullingmanager.savedFiles[index].filerecords?[recordIndex].rating = rating
            WriteSavedFilesJSON(cullingmanager.savedFiles)
        }
    }

    func handlePickerResult(_ result: Result<URL, Error>) {
        if case let .success(url) = result {
            // Security: Request persistent access
            if url.startAccessingSecurityScopedResource() {
                let source = FolderSource(name: url.lastPathComponent, url: url)
                sources.append(source)
                selectedSource = source
            }
        }
    }

    func extractAllJPGS() {
        Task {
            creatingthumbnails = true

            let handlers = CreateFileHandlers().createFileHandlers(
                fileHandler: fileHandler,
                maxfilesHandler: maxfilesHandler
            )

            let extract = ExtractAndSaveJPGs()
            await extract.setFileHandlers(handlers)
            guard let url = selectedSource?.url else { return }
            await extract.extractAndSaveAlljpgs(from: url, fullSize: false)

            creatingthumbnails = false
        }
    }
}
