//
//  CachedThumbnailView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 21/01/2026.
//

import SwiftUI

struct CachedThumbnailView: View {
    let url: URL

    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600, maxHeight: 600)
                    .shadow(radius: 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                ContentUnavailableView("Select an Image", systemImage: "photo")
            }
        }
        // The .task modifier cancels automatically if the user switches selection quickly
        .task(id: url) {
            isLoading = true
            // Offload to background actor
            image = await DefaultThumbnailProvider.shared.thumbnail(for: url, targetSize: 500)
            isLoading = false
        }
    }
}
