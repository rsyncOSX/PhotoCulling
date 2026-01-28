import SwiftUI

struct PhotoGridView: View {
    // Use @State for Observable objects in the view that owns them
    @Bindable var cullingmanager: ObservableCullingManager
    var files: [FileItem]
    let photoURL: URL?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == photoURL }) {
                    if let filerecords = cullingmanager.savedFiles[index].filerecords {
                        let localfiles = filerecords.compactMap { record in record.fileName as? String }
                        ForEach(localfiles.sorted(), id: \.self) { photo in
                            let photoURL = files.first(where: { $0.name == photo })?.url
                            PhotoItemView(
                                photo: photo,
                                photoURL: photoURL,
                                cullingmanager: cullingmanager
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}
