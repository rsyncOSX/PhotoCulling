import SwiftUI

struct PhotoGridView: View {
    // Use @State for Observable objects in the view that owns them
    @Bindable var cullingmanager: ObservableCullingManager
    var files: [FileItem]
    let photoURL: URL?

    var body: some View {
        Text("Hello, World!")
        /*
         FIX
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                if let index = cullingmanager.savedFiles.firstIndex(where: { $0.catalog == photoURL }) {
                    if let filerecords = cullingmanager.savedFiles[index].filerecords {
                        ForEach(filerecords.sorted(by: { String(describing: $0) < String(describing: $1) }),
                                id: \.self) { photo in
                            let photoURL = files.first(where: { $0.name == String(describing: photo) })?.url
                            PhotoItemView(
                                photo: String(describing: photo),
                                photoURL: photoURL,
                                cullingmanager: cullingmanager
                            )
                        }
                    }
                }
            }
            .padding()
        }
         */
    }
}
