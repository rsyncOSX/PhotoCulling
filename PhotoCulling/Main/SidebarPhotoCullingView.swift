import OSLog
import SwiftUI
import UniformTypeIdentifiers

extension KeyPath<FileItem, String>: @unchecked @retroactive Sendable {}

struct SidebarPhotoCullingView: View {
    @Environment(\.openWindow) var openWindow

    @Binding var nsImage: NSImage?
    @Binding var cgImage: CGImage?

    @State var sources: [FolderSource] = []
    @State var selectedSource: FolderSource?
    @State var files: [FileItem] = []

    @State var filteredFiles: [FileItem] = []

    @State var searchText = ""
    @State var selectedFileID: FileItem.ID?
    @State var sortOrder = [KeyPathComparator(\FileItem.name)]
    @State var isShowingPicker = false
    @State var isInspectorPresented = false

    @State var selectedFile: FileItem?
    @State var cullingmanager = ObservableCullingManager()

    @State var issorting: Bool = false
    @State private var processedURLs: Set<URL> = []

    @State var progress: Double = 0
    @State var max: Double = 0
    @State var creatingthumbnails: Bool = false

    @State var scanning: Bool = true

    @State var showingAlert: Bool = false

    // Focus buttons from the menu
    @State var focustogglerow: Bool = false
    @State var focusaborttask: Bool = false

    /// Copy tasks
    @State var showcopytask: Bool = false

    /// Alert type enum and state
    enum ToolbarAlertType {
        case extractJPGs
        case clearToggledFiles
        case clearMemoryandThumbnails
    }

    /// @State private var showingAlert = false
    @State var alertType: ToolbarAlertType?

    var body: some View {
        NavigationSplitView {
            // --- SIDEBAR ---
            CatalogSidebarView(
                sources: $sources,
                selectedSource: $selectedSource,
                isShowingPicker: $isShowingPicker,
                cullingManager: cullingmanager
            )
        } content: {
            // --- MIDDLE COLUMN (TABLE) ---
            FileContentView(
                selectedSource: selectedSource,
                files: files,
                scanning: scanning,
                creatingThumbnails: creatingthumbnails,
                issorting: issorting,
                progress: progress,
                max: max,
                isShowingPicker: $isShowingPicker,
                filetableview: AnyView(filetableview)
            )
            .navigationTitle(selectedSource?.name ?? "Files")
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search in \(selectedSource?.name ?? "catalog")...")
            .toolbar { toolbarContent }
            .focusedSceneValue(\.togglerow, $focustogglerow)
            .sheet(isPresented: $showcopytask) { CopyTasksView(selectedSource: $selectedSource,
                                                               fileHandler: fileHandler,
                                                               processTermination: processtermination)
            }
            .alert(isPresented: $showingAlert) {
                switch alertType {
                case .extractJPGs:
                    return Alert(
                        title: Text("Extract JPGs"),
                        message: Text("Are you sure you want to extract JPG images from ARW files?"),
                        primaryButton: .destructive(Text("Extract")) {
                            extractAllJPGS()
                        },
                        secondaryButton: .cancel()
                    )

                case .clearToggledFiles:
                    return Alert(
                        title: Text("Clear Toggled Files"),
                        message: Text("Are you sure you want to clear all toggled files?"),
                        primaryButton: .destructive(Text("Clear")) {
                            if let url = selectedSource?.url {
                                cullingmanager.resetSavedFiles(in: url)
                            }
                        },
                        secondaryButton: .cancel()
                    )

                case .clearMemoryandThumbnails:
                    return Alert(
                        title: Text("Reset Memory and Cached Thumbnails Files"),
                        message: Text("Are you sure you want to reset?"),
                        primaryButton: .destructive(Text("Reset")) {
                            Task {
                                await ThumbnailProvider.shared.clearCaches()
                                sources.removeAll()
                                selectedSource = nil
                                filteredFiles.removeAll()
                                files.removeAll()
                                selectedFile = nil
                            }
                        },
                        secondaryButton: .cancel()
                    )

                case .none:
                    return Alert(title: Text("Unknown Action"))
                }
            }
        } detail: {
            // --- DETAIL VIEW ---
            FileDetailView(
                cgImage: $cgImage,
                nsImage: $nsImage,
                files: files,
                file: selectedFile,
                selectedFileID: selectedFileID
            )
        }
        .task {
            let handlers = CreateFileHandlers().createFileHandlers(
                fileHandler: fileHandler,
                maxfilesHandler: maxfilesHandler
            )
            await ThumbnailProvider.shared.setFileHandlers(handlers)
        }
        // --- RIGHT INSPECTOR ---
        .inspector(isPresented: $isInspectorPresented) {
            FileInspectorView(file: $selectedFile)
        }
        .fileImporter(isPresented: $isShowingPicker, allowedContentTypes: [.folder]) { result in
            handlePickerResult(result)
        }
        .onChange(of: selectedSource) {
            Task(priority: .background) {
                if let url = selectedSource?.url {
                    files = await ScanFiles().scanFiles(url: url)
                    filteredFiles = await ScanFiles().sortFiles(
                        files,
                        by: sortOrder,
                        searchText: searchText
                    )

                    guard !files.isEmpty else {
                        scanning = false
                        return
                    }

                    scanning = false

                    cullingmanager.loadSavedFiles()

                    if processedURLs.contains(url) == false {
                        processedURLs.insert(url)

                        creatingthumbnails = true

                        await ThumbnailProvider.shared.preloadCatalog(
                            at: url,
                            targetSize: ThumbnailSize.preview
                        )

                        creatingthumbnails = false
                    }
                }
            }
        }
        .onChange(of: sortOrder) {
            Task(priority: .background) {
                issorting = true
                filteredFiles = await ScanFiles().sortFiles(
                    files,
                    by: sortOrder,
                    searchText: searchText
                )
                issorting = false
            }
        }
        .onChange(of: searchText) {
            Task(priority: .background) {
                issorting = true
                filteredFiles = await ScanFiles().sortFiles(
                    files,
                    by: sortOrder,
                    searchText: searchText
                )
                issorting = false
            }
        }

        if focustogglerow == true { labeltogglerow }
        if focusaborttask { labelaborttask }
    }

    var labeltogglerow: some View {
        Label("", systemImage: "play.fill")
            .onAppear {
                focustogglerow = false
                if let index = files.firstIndex(where: { $0.id == selectedFileID }) {
                    let fileitem = files[index]
                    handleToggleSelection(for: fileitem)
                }
            }
    }

    var labelaborttask: some View {
        Label("", systemImage: "play.fill")
            .onAppear {
                focusaborttask = false
                abort()
            }
    }

    func abort() {}

    func fileHandler(_ update: Int) {
        progress = Double(update)
    }

    func maxfilesHandler(_ maxfiles: Int) {
        max = Double(maxfiles)
    }

    func processtermination(output: [String]?, _: Int?) {
        print(output ?? [])
    }
}
