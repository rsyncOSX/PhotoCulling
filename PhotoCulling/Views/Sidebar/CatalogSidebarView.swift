import SwiftUI

struct CatalogSidebarView: View {
    @Binding var sources: [FolderSource]
    @Binding var selectedSource: FolderSource?
    @Binding var isShowingPicker: Bool

    let cullingManager: ObservableCullingManager

    var body: some View {
        List(sources, selection: $selectedSource) { source in
            NavigationLink(value: source) {
                Label(source.name, systemImage: "folder.badge.plus")
                    .badge("(" + String(cullingManager.countSelectedFiles(in: source.url)) + ")")
            }
        }
        .navigationTitle("Catalogs")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button(action: { isShowingPicker = true }, label: {
                    Label("Add Catalog", systemImage: "plus")
                })
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Divider()

                CacheStatisticsView(thumbnailProvider: ThumbnailProvider.shared)
            }
            .padding()
        }
    }
}
