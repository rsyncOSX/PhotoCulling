//
//  CacheSettingsTab.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 08/02/2026.
//

import SwiftUI

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
                                    Text(formatBytes(cacheConfig?.totalCostLimit ?? 0))
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
                // The ThumbnailProvider.init get the saved settings an update cost by
                // setCacheCostsFromSavedSettings()
                await ThumbnailProvider.shared.setCostPerPixel(settingsManager.thumbnailCostPerPixel)
                cacheConfig = await ThumbnailProvider.shared.getCacheCostsAfterSettingsUpdate()
            }
            .task(id: settingsManager.memoryCacheSizeMB) {
                await ThumbnailProvider.shared.setCacheCostsFromSavedSettings()
                cacheConfig = await ThumbnailProvider.shared.getCacheCostsAfterSettingsUpdate()
            }
            .task(id: settingsManager.thumbnailCostPerPixel) {
                await ThumbnailProvider.shared.setCacheCostsFromSavedSettings()
                await ThumbnailProvider.shared.setCostPerPixel(settingsManager.thumbnailCostPerPixel)
                cacheConfig = await ThumbnailProvider.shared.getCacheCostsAfterSettingsUpdate()
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
