import Foundation
import Observation
import OSLog
import OSAKit

@Observable @MainActor
final class SidebarPhotoCullingViewModel {
    var sources: [FolderSource] = []
    var selectedSource: FolderSource?
    var files: [FileItem] = []
    var filteredFiles: [FileItem] = []
    var searchText = ""
    var selectedFileID: FileItem.ID?
    var sortOrder = [KeyPathComparator(\FileItem.name)]
    var isShowingPicker = false
    var isInspectorPresented = false
    var selectedFile: FileItem?
    var issorting: Bool = false
    var progress: Double = 0
    var max: Double = 0
    var creatingthumbnails: Bool = false
    var scanning: Bool = true
    var showingAlert: Bool = false
    var focustogglerow: Bool = false
    var focusaborttask: Bool = false
    var focusnavigateUp: Bool = false
    var focusnavigateDown: Bool = false
    var focusPressEnter: Bool = false
    var showcopytask: Bool = false
    var alertType: SidebarAlertView.AlertType?
    var sheetType: SheetType? = .copytasksview
    var remotedatanumbers: RemoteDataNumbers?
    var rating: Int = 0
    
    // Zoom window state
    var zoomCGImageWindowFocused: Bool = false
    var zoomNSImageWindowFocused: Bool = false
    var pendingCGImageUpdate: CGImage?
    var pendingNSImageUpdate: NSImage?

    var cullingmanager = ObservableCullingManager()
    private var processedURLs: Set<URL> = []

    func handleSourceChange(url: URL) async {
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

        if !processedURLs.contains(url) {
            processedURLs.insert(url)
            creatingthumbnails = true

            await ThumbnailProvider.shared.preloadCatalog(
                at: url,
                targetSize: ThumbnailSize.preview
            )

            creatingthumbnails = false
        }
    }

    func handleSortOrderChange() async {
        issorting = true
        filteredFiles = await ScanFiles().sortFiles(
            files,
            by: sortOrder,
            searchText: searchText
        )
        issorting = false
    }

    func handleSearchTextChange() async {
        issorting = true
        filteredFiles = await ScanFiles().sortFiles(
            files,
            by: sortOrder,
            searchText: searchText
        )
        issorting = false
    }

    func clearCaches() async {
        await ThumbnailProvider.shared.clearCaches()
        sources.removeAll()
        selectedSource = nil
        filteredFiles.removeAll()
        files.removeAll()
        selectedFile = nil
    }

    func fileHandler(_ update: Int) {
        progress = Double(update)
    }

    func maxfilesHandler(_ maxfiles: Int) {
        max = Double(maxfiles)
    }

    func abort() {
        // Implementation deferred - abort functionality to be added
    }

    func extractRatedfilenames(_ rating: Int) -> [String] {
        let result = filteredFiles.compactMap { file in
            (getRating(for: file) >= rating) ? file : nil
        }
        return result.map { $0.name }
    }

    func extractTaggedfilenames() -> [String] {
        if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == selectedSource?.url }),
           let taggedfilerecords = cullingmanager.savedFiles[index].filerecords {
            return taggedfilerecords.compactMap { $0.fileName }
        }
        return []
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
}
