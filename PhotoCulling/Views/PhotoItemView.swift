//
//  PhotoItemView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 21/01/2026.
//

import OSLog
import SwiftUI

struct PhotoItemView: View {
    let photo: String
    let photoURL: URL?
    var onSelected: () -> Void = {}

    @Bindable var cullingmanager: ObservableCullingManager

    @State private var thumbnailImage: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading) {
                ZStack {
                    if let thumbnailImage {
                        Image(nsImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: CGFloat(ThumbnailSize.grid),
                                height: CGFloat(ThumbnailSize.grid)
                            )
                            .clipped()
                    } else if isLoading {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: CGFloat(ThumbnailSize.grid))
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                            }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: CGFloat(ThumbnailSize.grid))

                            Label("No image available", systemImage: "xmark")
                        }
                    }
                }
                .background(setbackground() ? Color.blue.opacity(0.2) : Color.clear)

                Text(photo)
                    .font(.caption)
                    .lineLimit(2)
            }

            if setbackground() {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(5)
            }
        }
        .onTapGesture {
            onSelected()
        }
        .task(id: photoURL) {
            guard let url = photoURL else { return }
            Logger.process.debugMessageOnly("PhotoItemView (in GRID) loading thumbnail for \(url)")
            isLoading = true
            // Most likely a thumbnail is received from the populated NSCache<NSURL, NSImage>().
            thumbnailImage = await ThumbnailProvider.shared.thumbnail(
                for: url,
                targetSize: ThumbnailSize.grid
            )
            isLoading = false
        }
    }

    func setbackground() -> Bool {
        guard let photoURL else { return false }
        // Find the saved file entry matching this photoURL
        guard let entry = cullingmanager.savedFiles.first(where: { $0.catalog == photoURL }) else {
            return false
        }
        // Check if any filerecord has a matching fileName
        if let records = entry.filerecords {
            return records.contains { $0.fileName == photo }
        }
        return false
    }
}
