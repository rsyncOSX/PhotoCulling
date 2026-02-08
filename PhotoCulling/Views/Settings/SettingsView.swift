//
//  SettingsView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 05/02/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) var settingsManager
    @State private var showResetConfirmation = false

    var body: some View {
        TabView {
            CacheSettingsTab()
                .tabItem {
                    Label("Cache", systemImage: "memorychip.fill")
                }

            ThumbnailSizesTab()
                .tabItem {
                    Label("Thumbnails", systemImage: "photo.fill")
                }

            CacheStatisticsView(thumbnailProvider: ThumbnailProvider.shared)
                .tabItem {
                    Label("Cache statistics", systemImage: "numbers")
                }
        }
        .padding(20)
        .frame(width: 450, height: 450)
    }
}
