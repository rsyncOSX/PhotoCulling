import SwiftUI

struct PhotoGridView: View {
    // Use @State for Observable objects in the view that owns them
    @Bindable var cullingmanager: ObservableCullingManager
    var files: [FileItem]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                ForEach(Array(cullingmanager.selectedFiles).sorted(), id: \.self) { photo in
                    let photoURL = files.first(where: { $0.name == photo })?.url
                    PhotoItemView(photo: photo, photoURL: photoURL, cullingmanager: cullingmanager)
                }
            }
            .padding()
        }
    }
}
