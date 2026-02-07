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
        }
        .padding(20)
        .frame(width: 450, height: 450)
    }
}

// MARK: - Cache Settings Tab

struct CacheSettingsTab: View {
    @Environment(SettingsManager.self) var settingsManager
    @State private var showResetConfirmation = false
    @State private var currentDiskCacheSize: Int = 0
    @State private var isLoadingDiskCacheSize = false
    @State private var isPruningDiskCache = false

    @State private var cacheConfig: CacheConfig?

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                // Memory Cache Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Memory & Disk Cache")
                        .font(.system(size: 14, weight: .semibold))

                    Divider()

                    // Cache Size and Max Thumbnails - Horizontal Layout
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Higher values cache more thumbnails in memory")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            // Cache Size
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "memorychip")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("Memory")
                                        .font(.system(size: 10, weight: .medium))
                                    Spacer()
                                    Text("\(settingsManager.memoryCacheSizeMB) MB")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                }
                                Slider(
                                    value: Binding<Double>(
                                        get: { Double(settingsManager.memoryCacheSizeMB) },
                                        set: { settingsManager.memoryCacheSizeMB = Int($0) }
                                    ),
                                    in: 100 ... 2000,
                                    step: 50
                                )
                                .frame(height: 18)
                            }

                            // Max Cached Thumbnails
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.stack")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("Max Thumb")
                                        .font(.system(size: 10, weight: .medium))
                                    Spacer()
                                    Text("\(settingsManager.maxCachedThumbnails)")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                }
                                Slider(
                                    value: Binding<Double>(
                                        get: { Double(settingsManager.maxCachedThumbnails) },
                                        set: { settingsManager.maxCachedThumbnails = Int($0) }
                                    ),
                                    in: 10 ... 200,
                                    step: 10
                                )
                                .frame(height: 18)
                            }
                        }

                        // Current Disk Cache Size with Prune Button
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "internaldrive")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Current use: ")
                                    .font(.system(size: 12, weight: .medium))

                                if isLoadingDiskCacheSize {
                                    ProgressView()
                                        .fixedSize()
                                } else {
                                    Text(formatBytes(currentDiskCacheSize))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                            }

                            Spacer()

                            ConditionalGlassButton(
                                systemImage: "trash",
                                text: "Prune Disk Cache",
                                helpText: "Prune disk cache to free up space."
                            ) {
                                pruneDiskCache()
                            }
                            .disabled(isPruningDiskCache)
                        }
                        .padding(12)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)

                        // Cache Limits Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cache Limits")
                                .font(.system(size: 12, weight: .semibold))

                            Divider()

                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Cost Limit")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(formatBytes(cacheConfig?.totalCostLimit ?? 524_288_000))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Count Limit")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    if let countLimit = cacheConfig?.countLimit {
                                        Text("\(String(countLimit))")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    }
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cost Per Pixel")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    if let costPerPixel = cacheConfig?.costPerPixel {
                                        Text("\(String(costPerPixel)) bytes")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()

            HStack {
                ConditionalGlassButton(
                    systemImage: "square.and.arrow.down.fill",
                    text: "Save Settings",
                    helpText: "Save settings"
                ) {
                    Task {
                        await settingsManager.saveSettings()
                    }
                }

                // Reset Button
                Button(
                    action: { showResetConfirmation = true },
                    label: {
                        Label("Reset to Defaults", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .medium))
                    }
                )
                .buttonStyle(RefinedGlassButtonStyle())
                .confirmationDialog(
                    "Reset Settings",
                    isPresented: $showResetConfirmation,
                    actions: {
                        Button("Reset", role: .destructive) {
                            Task {
                                await settingsManager.resetToDefaultsMemoryCache()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    },
                    message: {
                        Text("Are you sure you want to reset all settings to their default values?")
                    }
                )
            }
            .onAppear(perform: refreshDiskCacheSize)
            .task {
                // Initialize ThumbnailProvider with saved cost per pixel setting
                await ThumbnailProvider.shared.setCostPerPixel(settingsManager.thumbnailCostPerPixel)
                cacheConfig = await ThumbnailProvider.shared.exportCalculatedSavedSettings()
            }
        }
    }

    private func refreshDiskCacheSize() {
        isLoadingDiskCacheSize = true
        Task {
            let size = await ThumbnailProvider.shared.getDiskCacheSize()
            await MainActor.run {
                currentDiskCacheSize = size
                isLoadingDiskCacheSize = false
            }
        }
    }

    private func pruneDiskCache() {
        isPruningDiskCache = true
        Task {
            await ThumbnailProvider.shared.pruneDiskCache(maxAgeInDays: 0)
            // Refresh the size after pruning
            let size = await ThumbnailProvider.shared.getDiskCacheSize()
            await MainActor.run {
                currentDiskCacheSize = size
                isPruningDiskCache = false
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes == 0 { return "0 B" }
        let units = ["B", "KB", "MB", "GB"]
        let unitIndex = Int(log2(Double(bytes)) / 10)
        let size = Double(bytes) / pow(1024, Double(unitIndex))
        return String(format: "%.1f %@", size, units[min(unitIndex, units.count - 1)])
    }
}

// MARK: - Thumbnail Sizes Tab

struct ThumbnailSizesTab: View {
    @Environment(SettingsManager.self) var settingsManager
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                // Thumbnail Settings Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thumbnail Sizes")
                        .font(.system(size: 14, weight: .semibold))

                    Divider()

                    // Grid Size
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Grid Thumbnail Size", systemImage: "square.grid.2x2")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(settingsManager.thumbnailSizeGrid) px")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { Double(settingsManager.thumbnailSizeGrid) },
                                set: { settingsManager.thumbnailSizeGrid = Int($0) }
                            ),
                            in: 50 ... 200,
                            step: 10
                        )
                        Text("Size for grid view thumbnails")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    // Preview Size
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Preview Thumbnail Size", systemImage: "photo")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(settingsManager.thumbnailSizePreview) px")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { Double(settingsManager.thumbnailSizePreview) },
                                set: { settingsManager.thumbnailSizePreview = Int($0) }
                            ),
                            in: 256 ... 2048,
                            step: 128
                        )
                        Text("Size for preview view thumbnails")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }

                    // Cost Per Pixel
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Quality/Memory Trade-off", systemImage: "function")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(settingsManager.thumbnailCostPerPixel) bytes")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        Slider(
                            value: Binding<Double>(
                                get: { Double(settingsManager.thumbnailCostPerPixel) },
                                set: { newValue in
                                    let intValue = Int(newValue)
                                    settingsManager.thumbnailCostPerPixel = intValue
                                    Task {
                                        await ThumbnailProvider.shared.setCostPerPixel(intValue)
                                    }
                                }
                            ),
                            in: 1 ... 8,
                            step: 1
                        )
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Lower values = lower quality/less memory.")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Text("Higher values = better quality/more memory")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }

                            // Calculate estimated costs
                            let gridCost = (settingsManager.thumbnailSizeGrid *
                                settingsManager.thumbnailSizeGrid *
                                settingsManager.thumbnailCostPerPixel) / 1024
                            let previewCost = (settingsManager.thumbnailSizePreview *
                                settingsManager.thumbnailSizePreview *
                                settingsManager.thumbnailCostPerPixel) / 1024
                            let fullCost = (settingsManager.thumbnailSizeFullSize *
                                settingsManager.thumbnailSizeFullSize *
                                settingsManager.thumbnailCostPerPixel) / 1024

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Est. Grid: \(gridCost) KB")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Text("Est. Preview: \(previewCost) KB")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.secondary)
                                Text("Est. Full: \(fullCost) KB")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            }

            Spacer()

            HStack {
                ConditionalGlassButton(
                    systemImage: "square.and.arrow.down.fill",
                    text: "Save Settings",
                    helpText: "Save settings"
                ) {
                    Task {
                        await settingsManager.saveSettings()
                    }
                }

                // Reset Button
                Button(
                    action: { showResetConfirmation = true },
                    label: {
                        Label("Reset to Defaults", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .medium))
                    }
                )
                .buttonStyle(RefinedGlassButtonStyle())
                .confirmationDialog(
                    "Reset Settings",
                    isPresented: $showResetConfirmation,
                    actions: {
                        Button("Reset", role: .destructive) {
                            Task {
                                await settingsManager.resetToDefaultsThumbnails()
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
        .onAppear {
            // Initialize ThumbnailProvider with saved cost per pixel setting
            Task {
                await ThumbnailProvider.shared.setCostPerPixel(settingsManager.thumbnailCostPerPixel)
            }
        }
    }
}
