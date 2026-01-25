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
                systemImage: "plus.magnifyingglass",
                text: "",
                helpText: "Zoom"
            ) {
                openWindow(id: "zoom-window-arw")
            }
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
                    helpText: "Clear preseselect files"
                ) {
                    cullingmanager.selectedFiles.removeAll()
                    cullingmanager.numberofPreselectedFiles.removeAll()
                    cullingmanager.saveToJSON()
                }
            }
        }

        ToolbarItem {
            ConditionalGlassButton(
                systemImage: "document.on.trash",
                text: "",
                helpText: "Clear memory and disk cache"
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
                
                Task {
                    let extractor = ExtractEmbeddedPreviewDownsampling()
                    if files[index].url.pathExtension.lowercased() == "arw" {
                        // 1. Extract the preview
                        if let mycgImage = await extractor.extractEmbeddedPreview(from: files[index].url) {
                            cgImage = mycgImage
                             // 2. Save it to disk
                            // await extractor.save(image: mycgImage, originalURL: files[index].url)
                        } else {
                            print("Could not extract preview.")
                        }
                    } else {
                        // nsImage = await ThumbnailProvider.shared.thumbnail(for: files[index].url, targetSize: 2560)
                    }
                }
                
            } else {
                isInspectorPresented = false
            }
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
}
