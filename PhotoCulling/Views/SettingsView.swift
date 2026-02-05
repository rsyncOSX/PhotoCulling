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
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
    }
}

// MARK: - Cache Settings Tab

struct CacheSettingsTab: View {
    @Environment(SettingsManager.self) var settingsManager
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                // Memory Cache Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memory Cache")
                        .font(.system(size: 14, weight: .semibold))

                    Divider()

                    // Cache Size
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Memory Cache Size", systemImage: "memorychip")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(settingsManager.memoryCacheSizeMB) MB")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { Double(settingsManager.memoryCacheSizeMB) },
                                set: { settingsManager.memoryCacheSizeMB = Int($0) }
                            ),
                            in: 100 ... 2000,
                            step: 50
                        )
                        Text("Higher values cache more thumbnails in memory")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    // Max Cached Thumbnails
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Max Cached Thumbnails", systemImage: "photo.stack")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(settingsManager.maxCachedThumbnails)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { Double(settingsManager.maxCachedThumbnails) },
                                set: { settingsManager.maxCachedThumbnails = Int($0) }
                            ),
                            in: 10 ... 200,
                            step: 10
                        )
                        Text("Number of thumbnail images to keep in memory")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

                // Disk Cache Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Disk Cache")
                        .font(.system(size: 14, weight: .semibold))

                    Divider()

                    // Auto Load Disk Cache
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(
                            isOn: Binding<Bool>(
                                get: { settingsManager.autoLoadDiskCache },
                                set: { settingsManager.autoLoadDiskCache = $0 }
                            )
                        ) {
                            Label("Auto-load Disk Cache at Startup", systemImage: "gear")
                                .font(.system(size: 12, weight: .medium))
                        }
                        Text("Automatically populate memory cache from disk cache when app starts")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    // Disk Cache Size
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Disk Cache Size", systemImage: "internaldrive")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(settingsManager.diskCacheSizeMB) MB")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { Double(settingsManager.diskCacheSizeMB) },
                                set: { settingsManager.diskCacheSizeMB = Int($0) }
                            ),
                            in: 500 ... 5000,
                            step: 100
                        )
                        Text("Maximum size of cached files on disk")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()

            // Reset Button
            Button(
                action: { showResetConfirmation = true },
                label: {
                    Label("Reset to Defaults", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12, weight: .medium))
                }
            )
            .buttonStyle(.bordered)
            .confirmationDialog(
                "Reset Settings",
                isPresented: $showResetConfirmation,
                actions: {
                    Button("Reset", role: .destructive) {
                        Task {
                            await settingsManager.resetToDefaults()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                },
                message: {
                    Text("Are you sure you want to reset all settings to their default values?")
                }
            )
        }
    }
}

#Preview {
    SettingsView()
        .environment(SettingsManager.shared)
}
