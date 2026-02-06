//
//  SettingsManager.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 05/02/2026.
//

// @Environment(SettingsManager.self) var settingsManager

import Foundation
import OSLog

/// Observable settings manager for app configuration
/// Persists settings to JSON in Application Support directory
@Observable
class SettingsManager {
    static let shared = SettingsManager()

    // MARK: - Memory Cache Settings

    /// Maximum memory cache size in MB (default: 500)
    var memoryCacheSizeMB: Int = 500 {
        didSet {
            Task {
                await saveSettings()
            }
        }
    }

    /// Number of cached thumbnails to keep in memory (default: 100)
    var maxCachedThumbnails: Int = 100 {
        didSet {
            Task {
                await saveSettings()
            }
        }
    }

    // MARK: - Thumbnail Size Settings

    /// Grid thumbnail size in pixels (default: 100)
    var thumbnailSizeGrid: Int = 100 {
        didSet {
            Task {
                await saveSettings()
            }
        }
    }

    /// Preview thumbnail size in pixels (default: 1024)
    var thumbnailSizePreview: Int = 1024 {
        didSet {
            Task {
                await saveSettings()
            }
        }
    }

    /// Full size thumbnail in pixels (default: 8700)
    var thumbnailSizeFullSize: Int = 8700 {
        didSet {
            Task {
                await saveSettings()
            }
        }
    }

    /// Estimated cost per pixel for thumbnail (in bytes, default: 4 for RGBA)
    var thumbnailCostPerPixel: Int = 4 {
        didSet {
            Task {
                await saveSettings()
            }
        }
    }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.photoculling", category: "SettingsManager")
    private let settingsFileName = "settings.json"

    private var settingsURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appFolder = appSupport.appendingPathComponent("PhotoCulling", isDirectory: true)
        return appFolder.appendingPathComponent(settingsFileName)
    }

    // MARK: - Initialization

    private init() {
        Task {
            await loadSettings()
        }
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
                logger.debug("Settings file not found, using defaults")
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

            logger.debug("Settings loaded successfully")
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription)")
        }
    }

    /// Save settings to JSON file
    func saveSettings() async {
        do {
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
            logger.debug("Settings saved successfully")
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription)")
        }
    }

    /// Reset settings to defaults
    func resetToDefaults() async {
        await MainActor.run {
            self.memoryCacheSizeMB = 500
            self.maxCachedThumbnails = 100
            self.thumbnailSizeGrid = 100
            self.thumbnailSizePreview = 1024
            self.thumbnailSizeFullSize = 8700
            self.thumbnailCostPerPixel = 4
        }
        await saveSettings()
    }
}

// MARK: - Codable Model

private struct SavedSettings: Codable {
    let memoryCacheSizeMB: Int
    let maxCachedThumbnails: Int
    let thumbnailSizeGrid: Int
    let thumbnailSizePreview: Int
    let thumbnailSizeFullSize: Int
    let thumbnailCostPerPixel: Int
}
