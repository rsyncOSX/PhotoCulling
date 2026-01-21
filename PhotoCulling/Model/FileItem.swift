import SwiftUI
import UniformTypeIdentifiers

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let type: String
    let dateModified: Date

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct FolderSource: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL
}
