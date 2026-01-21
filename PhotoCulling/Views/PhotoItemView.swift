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
                            .frame(width: 100, height: 100)
                            .clipped()
                    } else if isLoading {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 100)
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                            }
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 100)
                    }
                }
                .background(cullingmanager.selectedFiles.contains(photo) ? Color.blue.opacity(0.2) : Color.clear)
                .onTapGesture {
                    cullingmanager.toggleSelection(filename: photo)
                }

                Text(photo)
                    .font(.caption)
                    .lineLimit(2)
            }

            if cullingmanager.selectedFiles.contains(photo) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .padding(5)
            }
        }
        .task(id: photoURL) {
            guard let url = photoURL else { return }
            Logger.process.debugMessageOnly("PhotoItemView loading thumbnail for \(url)")
            isLoading = true
            thumbnailImage = await ThumbnailCacheService.shared.thumbnail(for: url, targetSize: 200)
            isLoading = false
        }
    }
}
