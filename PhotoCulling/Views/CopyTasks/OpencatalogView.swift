import SwiftUI
import UniformTypeIdentifiers

struct OpencatalogView: View {
    @Binding var selecteditem: String
    @State private var isImporting: Bool = false
    let catalogs: Bool
    let bookmarkKey: String

    var body: some View {
        Button(action: {
            isImporting = true
        }, label: {
            if catalogs {
                Image(systemName: "folder.fill")
                    .foregroundColor(Color(.blue))
            } else {
                Image(systemName: "text.document.fill")
                    .foregroundColor(Color(.blue))
            }
        })
        .fileImporter(isPresented: $isImporting,
                      allowedContentTypes: [uutype],
                      onCompletion: { result in
                          switch result {
                          case let .success(url):
                              print("DEBUG: Selected URL: \(url.path)")
                              selecteditem = url.path

                              // Try to create bookmark (may fail for some paths)
                              do {
                                  let bookmarkData = try url.bookmarkData(
                                      options: .withSecurityScope,
                                      includingResourceValuesForKeys: nil,
                                      relativeTo: nil
                                  )
                                  UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
                                  print("DEBUG: Bookmark saved for key: \(bookmarkKey)")
                                  print("DEBUG: Bookmark data size: \(bookmarkData.count) bytes")
                              } catch {
                                  print("WARNING: Could not create bookmark, but path is still set: \(error)")
                                  // Path is available in selecteditem even without bookmark
                              }

                          case let .failure(error):
                              print("ERROR: File picker error: \(error)")
                          }
                      })
    }

    var uutype: UTType {
        if catalogs {
            .directory
        } else {
            .item
        }
    }
}
