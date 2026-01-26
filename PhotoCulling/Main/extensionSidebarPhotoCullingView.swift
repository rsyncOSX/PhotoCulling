//
//  extensionSidebarPhotoCullingView.swift
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
                Text("\(filteredFiles.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }

        if cullingmanager.selectedFiles.isEmpty == false {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "trash.fill",
                    text: "",
                    helpText: "Clear toggled files"
                ) {
                    cullingmanager.selectedFiles.removeAll()
                    cullingmanager.numberofPreselectedFiles.removeAll()
                    cullingmanager.saveToJSON()
                }
                .disabled(creatingthumbnails)
            }
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
                        Image(systemName: cullingmanager.selectedFiles.contains(file.name) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(.blue)
                    })
                    .buttonStyle(.plain)
                }
                .width(30)
                TableColumn("Name", value: \.name)
                TableColumn("Size", value: \.size) { file in
                    Text(file.formattedSize).monospacedDigit()
                }
                TableColumn("Type", value: \.type)
                TableColumn("Modified", value: \.dateModified) { file in
                    Text(file.dateModified, style: .date)
                }
            }

            if cullingmanager.selectedFiles.isEmpty == false {
                PhotoGridView(
                    cullingmanager: cullingmanager,
                    files: filteredFiles
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
    }

    // MARK: - Helper Functions

    func handleToggleSelection(for file: FileItem) {
        cullingmanager.toggleSelection(
            in: file.url,
            filename: file.name
        )
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

    func syncSavedSelections() {
        // Sync the selected file with cullingmanager state
        // If current selectedFile is no longer in cullingmanager, clear it
        if let currentFile = selectedFile, !cullingmanager.selectedFiles.contains(currentFile.name) {
            selectedFile = nil
            selectedFileID = nil
            isInspectorPresented = false
        }
    }

    func extractAllJPGS() {
        Task {
            creatingthumbnails = true

            let handlers = CreateFileHandlers().createFileHandlers(
                fileHandler: fileHandler,
                maxfilesHandler: maxfilesHandler
            )

            let extract = ExtractAndSaveAlljpgs()
            await extract.setFileHandlers(handlers)
            guard let url = selectedSource?.url else { return }
            await extract.extractAndSaveAlljpgs(from: url, fullSize: false)

            creatingthumbnails = false
        }
    }
}

