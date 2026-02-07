//
//  SettingsManager.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 05/02/2026.
//

// @Environment(SettingsManager.self) var settingsManager

import Foundation
import OSLog

// Observable settings manager for app configuration
// Persists settings to JSON in Application Support directory

@Observable
final class SettingsManager {
    @MainActor static let shared = SettingsManager()

    // MARK: - Initialization

    private init() {
        Task {
            await loadSettings()
        }
    }

    // MARK: - Memory Cache Settings

    /// Maximum memory cache size in MB (default: 500)
    var memoryCacheSizeMB: Int = 500
    /// Number of cached thumbnails to keep in memory (default: 100)
    var maxCachedThumbnails: Int = 100

    // MARK: - Thumbnail Size Settings

    /// Grid thumbnail size in pixels (default: 100)
    var thumbnailSizeGrid: Int = 100
    /// Preview thumbnail size in pixels (default: 1024)
    var thumbnailSizePreview: Int = 1024
    /// Full size thumbnail in pixels (default: 8700)
    var thumbnailSizeFullSize: Int = 8700
    /// Estimated cost per pixel for thumbnail (in bytes, default: 4 for RGBA)
    var thumbnailCostPerPixel: Int = 4

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.photoculling", category: "SettingsManager")
    private let settingsFileName = "settings.json"

    private var settingsURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent("PhotoCulling", isDirectory: true)
        return appFolder.appendingPathComponent(settingsFileName)
    }

    // MARK: - Public Methods

    /// Load settings from JSON file
    func loadSettings() async {
        do {
            let fileURL = settingsURL

            // Create directory if it doesn't exist
            let dirURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // If file doesn't exist, just use defaults
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                Logger.process.debugMessageOnly("Settings file not found, using defaults")
                return
            }

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let savedSettings = try decoder.decode(SavedSettings.self, from: data)

            await MainActor.run {
                self.memoryCacheSizeMB = savedSettings.memoryCacheSizeMB
                self.maxCachedThumbnails = savedSettings.maxCachedThumbnails
                self.thumbnailSizeGrid = savedSettings.thumbnailSizeGrid
                self.thumbnailSizePreview = savedSettings.thumbnailSizePreview
                self.thumbnailSizeFullSize = savedSettings.thumbnailSizeFullSize
                self.thumbnailCostPerPixel = savedSettings.thumbnailCostPerPixel
            }

            Logger.process.debugMessageOnly("SettingsManager: Settings loaded successfully")
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription)")
        }
    }

    /// Save settings to JSON file
    func saveSettings() async {
        do {
            // Validate settings before saving
            validateSettings()

            let fileURL = settingsURL

            // Create directory if it doesn't exist
            let dirURL = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: dirURL,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let settingsToSave = SavedSettings(
                memoryCacheSizeMB: memoryCacheSizeMB,
                maxCachedThumbnails: maxCachedThumbnails,
                thumbnailSizeGrid: thumbnailSizeGrid,
                thumbnailSizePreview: thumbnailSizePreview,
                thumbnailSizeFullSize: thumbnailSizeFullSize,
                thumbnailCostPerPixel: thumbnailCostPerPixel
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settingsToSave)

            try data.write(to: fileURL, options: .atomic)
            Logger.process.debugMessageOnly("Settings saved successfully")
        } catch {
            Logger.process.errorMessageOnly("Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// Validate settings and warn about potentially aggressive values
    private func validateSettings() {
        // Check minimum safety threshold
        let minimumCacheMB = 50
        if memoryCacheSizeMB < minimumCacheMB {
            let message = "Cache size: \(self.memoryCacheSizeMB)MB is below " +
                "recommended minimum of \(minimumCacheMB)MB. Performance may suffer."
            Logger.process.errorMessageOnly("\(message)")
        }

        // Check if cache size exceeds 50% of available system memory
        let availableMemory = ProcessInfo.processInfo.physicalMemory
        let availableMemoryMB = Int(availableMemory / (1024 * 1024))
        let memoryThresholdPercent = 50

        if memoryCacheSizeMB > availableMemoryMB * memoryThresholdPercent / 100 {
            let message = "Cache size: \(self.memoryCacheSizeMB)MB exceeds " +
                "\(memoryThresholdPercent)% of available system memory " +
                "(\(availableMemoryMB)MB). This may cause system memory pressure."
            Logger.process.errorMessageOnly("\(message)")
        }
    }

    /// Reset settings to defaults
    func resetToDefaultsMemoryCache() async {
        await MainActor.run {
            self.memoryCacheSizeMB = 500
            self.maxCachedThumbnails = 100
        }
        await saveSettings()
    }

    func resetToDefaultsThumbnails() async {
        await MainActor.run {
            self.thumbnailSizeGrid = 100
            self.thumbnailSizePreview = 1024
            self.thumbnailSizeFullSize = 8700
            self.thumbnailCostPerPixel = 4
        }
        await saveSettings()
    }

    @concurrent
    nonisolated func asyncgetsettings() async -> SavedSettings {
        await SavedSettings(
            memoryCacheSizeMB: self.memoryCacheSizeMB,
            maxCachedThumbnails: self.maxCachedThumbnails,
            thumbnailSizeGrid: self.thumbnailSizeGrid,
            thumbnailSizePreview: self.thumbnailSizePreview,
            thumbnailSizeFullSize: self.thumbnailSizeFullSize,
            thumbnailCostPerPixel: self.thumbnailCostPerPixel
        )
    }
}

// MARK: - Codable Model

struct SavedSettings: Codable {
    let memoryCacheSizeMB: Int
    let maxCachedThumbnails: Int
    let thumbnailSizeGrid: Int
    let thumbnailSizePreview: Int
    let thumbnailSizeFullSize: Int
    let thumbnailCostPerPixel: Int
}
