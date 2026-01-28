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
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Extract JPGs all files?"),
                    primaryButton: .default(Text("Extract")) {
                        guard selectedSource != nil else { return }

                        extractAllJPGS()
                    },
                    secondaryButton: .cancel {}
                )
            }
        } detail: {
            // --- DETAIL VIEW ---
            FileDetailView(file: selectedFile)
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
            if let file = selectedFile {
                FileInspectorView(file: file)
            }
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
                            targetSize: 2560
                        )

                        creatingthumbnails = false
                        max = 0
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
    }

    func fileHandler(_ update: Int) {
        progress = Double(update)
    }

    func maxfilesHandler(_ maxfiles: Int) {
        max = Double(maxfiles)
    }
}
