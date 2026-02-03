import OSLog
import SwiftUI
import UniformTypeIdentifiers

extension KeyPath<FileItem, String>: @unchecked @retroactive Sendable {}

struct SidebarPhotoCullingView: View {
    @Environment(\.openWindow) var openWindow

    @Binding var nsImage: NSImage?
    @Binding var cgImage: CGImage?

    @State var viewModel = SidebarPhotoCullingViewModel()

    var body: some View {
        NavigationSplitView {
            // --- SIDEBAR ---
            CatalogSidebarView(
                sources: $viewModel.sources,
                selectedSource: $viewModel.selectedSource,
                isShowingPicker: $viewModel.isShowingPicker,
                cullingManager: viewModel.cullingmanager
            )
        } content: {
            // --- MIDDLE COLUMN (TABLE) ---
            FileContentView(
                viewModel: viewModel,
                selectedSource: viewModel.selectedSource,
                files: viewModel.files,
                scanning: viewModel.scanning,
                creatingThumbnails: viewModel.creatingthumbnails,
                issorting: viewModel.issorting,
                progress: viewModel.progress,
                max: viewModel.max,
                isShowingPicker: $viewModel.isShowingPicker,
                filetableview: AnyView(filetableview)
            )
            .navigationTitle((viewModel.selectedSource?.name ?? "Files") + " (\(viewModel.filteredFiles.count) ARW files)")
            .searchable(
                text: $viewModel.searchText,
                placement: .toolbar,
                prompt: "Search in \(viewModel.selectedSource?.name ?? "catalog")..."
            )
            .toolbar { toolbarContent }
            .focusedSceneValue(\.togglerow, $viewModel.focustogglerow)
            .focusedSceneValue(\.navigateUp, $viewModel.focusnavigateUp)
            .focusedSceneValue(\.navigateDown, $viewModel.focusnavigateDown)
            .sheet(isPresented: $viewModel.showcopytask) {
                SidebarSheetContent(
                    viewModel: viewModel,
                    sheetType: $viewModel.sheetType,
                    selectedSource: $viewModel.selectedSource,
                    remotedatanumbers: $viewModel.remotedatanumbers,
                    showcopytask: $viewModel.showcopytask
                )
            }
            .alert(isPresented: $viewModel.showingAlert) {
                SidebarAlertView.alert(
                    type: viewModel.alertType,
                    selectedSource: viewModel.selectedSource,
                    cullingManager: viewModel.cullingmanager,
                    actions: (
                        extractJPGS: extractAllJPGS,
                        clearCaches: {
                            Task {
                                await viewModel.clearCaches()
                            }
                        }
                    )
                )
            }
        } detail: {
            // --- DETAIL VIEW ---
            FileDetailView(
                cgImage: $cgImage,
                nsImage: $nsImage,
                files: viewModel.files,
                file: viewModel.selectedFile,
                selectedFileID: viewModel.selectedFileID
            )
        }
        .task {
            let handlers = CreateFileHandlers().createFileHandlers(
                fileHandler: viewModel.fileHandler,
                maxfilesHandler: viewModel.maxfilesHandler
            )
            await ThumbnailProvider.shared.setFileHandlers(handlers)
        }
        // --- RIGHT INSPECTOR ---
        .inspector(isPresented: $viewModel.isInspectorPresented) {
            FileInspectorView(file: $viewModel.selectedFile)
        }
        .fileImporter(isPresented: $viewModel.isShowingPicker, allowedContentTypes: [.folder]) { result in
            handlePickerResult(result)
        }
        .onChange(of: viewModel.selectedSource) {
            Task(priority: .background) {
                if let url = viewModel.selectedSource?.url {
                    await viewModel.handleSourceChange(url: url)
                }
            }
        }
        .onChange(of: viewModel.sortOrder) {
            Task(priority: .background) {
                await viewModel.handleSortOrderChange()
            }
        }
        .onChange(of: viewModel.searchText) {
            Task(priority: .background) {
                await viewModel.handleSearchTextChange()
            }
        }

        if viewModel.focustogglerow == true { labeltogglerow }
        if viewModel.focusaborttask { labelaborttask }
    }

    var labeltogglerow: some View {
        Label("", systemImage: "play.fill")
            .onAppear {
                viewModel.focustogglerow = false
                if let index = viewModel.files.firstIndex(where: { $0.id == viewModel.selectedFileID }) {
                    let fileitem = viewModel.files[index]
                    handleToggleSelection(for: fileitem)
                }
            }
    }

    var labelaborttask: some View {
        Label("", systemImage: "play.fill")
            .onAppear {
                viewModel.focusaborttask = false
                abort()
            }
    }

    /// MUST FIX
    func abort() {
        viewModel.abort()
    }

    func fileHandler(_ update: Int) {
        viewModel.fileHandler(update)
    }

    func maxfilesHandler(_ maxfiles: Int) {
        viewModel.maxfilesHandler(maxfiles)
    }
}
