//
//  extension+SidebarPhotoCullingView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 21/01/2026.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

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

                openWindow(id: "zoom-window-arw")
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
            // Only allow double click if one item is selected and resolvable
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
            openWindow(id: "zoom-window-arw")
        }
        .onKeyPress(.space) {
            // Handle spacebar press to open zoom window
            guard let selectedID = selectedFileID,
                  let file = files.first(where: { $0.id == selectedID }) else { return .ignored }

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
            openWindow(id: "zoom-window-arw")
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
        if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == selectedSource?.url }) {
            return cullingmanager.savedFiles[index].filerecords != nil
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
