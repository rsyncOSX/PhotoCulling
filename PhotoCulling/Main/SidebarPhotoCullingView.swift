import OSLog
import SwiftUI
import UniformTypeIdentifiers

extension KeyPath<FileItem, String>: @unchecked @retroactive Sendable {}

struct SidebarPhotoCullingView: View {
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
    @State var cullingmanager = ObservableCullingManager(catalog: nil)

    @State var issorting: Bool = false

    var body: some View {
        NavigationSplitView {
            // --- SIDEBAR ---
            List(sources, selection: $selectedSource) { source in
                NavigationLink(value: source) {
                    Label(source.name, systemImage: "folder.badge.plus")
                }
            }
            .navigationTitle("Catalogs")
            .safeAreaInset(edge: .bottom) {
                Button(action: { isShowingPicker = true }, label: {
                    Label("Add Catalog", systemImage: "plus")
                })
                .buttonStyle(.bordered)
                .padding()
                .frame(maxWidth: .infinity)
            }
        } content: {
            // --- MIDDLE COLUMN (TABLE) ---
            Group {
                if selectedSource == nil {
                    // Empty State when no catalog is selected
                    ContentUnavailableView {
                        Label("No Catalog Selected", systemImage: "folder.badge.plus")
                    } description: {
                        Text("Select a folder from the sidebar or add a new one to start scanning.")
                    } actions: {
                        Button("Add Catalog") { isShowingPicker = true }
                    }
                } else if files.isEmpty {
                    ProgressView("Scanning directory...")
                } else {
                    ZStack {
                        filetableview

                        if issorting {
                            HStack {
                                ProgressView()

                                Text("Sorting files, please wait...")
                                    .font(.title)
                                    .foregroundColor(Color.green)
                            }
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .navigationTitle(selectedSource?.name ?? "Files")
            .searchable(text: $searchText, placement: .toolbar, prompt: "Search in \(selectedSource?.name ?? "catalog")...")
            .toolbar { toolbarContent }
        } detail: {
            // MARK: Detail View

            if let file = selectedFile {
                VStack(spacing: 20) {
                    CachedThumbnailView(url: file.url)

                    VStack {
                        Text(file.name)
                            .font(.headline)
                        Text(file.url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .padding()
                .frame(minWidth: 300, minHeight: 300)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "doc.text",
                    description: Text("Select a file to view its properties.")
                )
            }
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
        .onChange(of: selectedSource) { _, newSource in
            Task(priority: .background) {
                if let url = newSource?.url {
                    files = await ScanFiles().scanFiles(url: url)
                    filteredFiles = await ScanFiles().sortFiles(
                        files,
                        by: sortOrder,
                        searchText: searchText
                    )
                    cullingmanager.loadFromJSON(in: url)
                    syncSavedSelections()
                    await SonyThumbnailProvider.shared.preloadCatalog(at: url, targetSize: 500, recursive: false)
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
        .onChange(of: cullingmanager.selectedFiles) { _, _ in
            syncSavedSelections()
        }
    }
}
