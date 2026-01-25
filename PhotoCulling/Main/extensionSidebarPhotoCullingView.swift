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
        if arwfileisselected {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "plus.magnifyingglass",
                    text: "",
                    helpText: "Zoom"
                ) {
                    openWindow(id: "zoom-window-arw")
                }
            }
        } else {
            ToolbarItem {
                ConditionalGlassButton(
                    systemImage: "plus.magnifyingglass",
                    text: "",
                    helpText: "Zoom"
                ) {
                    openWindow(id: "zoom-window")
                }
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
                    let extractor = ExtractEmbeddedPreview()
                    if files[index].url.pathExtension.lowercased() == "arw" {
                        // 1. Extract the preview
                        if let mycgImage = extractor.extractEmbeddedPreview(from: files[index].url) {
                            cgImage = mycgImage
                            arwfileisselected = true
                            // 2. Save it to disk
                            if let savedURL = extractor.save(image: mycgImage, originalURL: files[index].url) {
                                print("Success! Image saved to: \(savedURL.path)")
                            } else {
                                print("Failed to save image.")
                            }
                        } else {
                            print("Could not extract preview.")
                        }
                        // cgImage = ExtractEmbeddedPreview().extractEmbeddedPreview(from: files[index].url)
                        // arwfileisselected = true
                    } else {
                        nsImage = await ThumbnailProvider.shared.thumbnail(for: files[index].url, targetSize: 2560)
                        arwfileisselected = false
                    }
                }
            } else {
                isInspectorPresented = false
            }
        }
    }

    var filetableview2: some View {
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

                TableColumn("Filename", value: \.name)

                TableColumn("Size") { file in
                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        .foregroundStyle(.secondary)
                }

                TableColumn("Type") { file in
                    Text(file.url.pathExtension.isEmpty ? "JPG" : file.url.pathExtension)
                        .padding(4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if cullingmanager.selectedFiles.isEmpty == false {
                PhotoGridView(
                    cullingmanager: cullingmanager,
                    files: filteredFiles
                )
            }
        }
    }

    // MARK: - Helper Functions

    func handleToggleSelection(for file: FileItem) {
        cullingmanager.toggleSelection(
            in: file.url,
            filename: file.name
        )
        /*
         // Update UI selection and inspector
         if cullingmanager.selectedFiles.contains(file.name) {
             selectedFileID = file.id
             selectedFile = file
             isInspectorPresented = true
         } else {
             // If this was the selected file and it's being deselected
             if selectedFile?.id == file.id {
                 selectedFile = nil
                 isInspectorPresented = false
             }
         }
         */
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
