//
//  PhotoCullingApp.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 19/01/2026.
//

import OSLog
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_: Notification) {}
}

@main
struct PhotoCullingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var nsImage: NSImage?
    @State private var cgImage: CGImage?
    @State private var zoomCGImageWindowFocused: Bool = false
    @State private var zoomNSImageWindowFocused: Bool = false
    @State private var settingsManager = SettingsManager.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(settingsManager)
        }

        Window("Photo Culling", id: "main-window") {
            SidebarPhotoCullingView(
                nsImage: $nsImage,
                cgImage: $cgImage,
                zoomCGImageWindowFocused: $zoomCGImageWindowFocused,
                zoomNSImageWindowFocused: $zoomNSImageWindowFocused
            )
            .environment(settingsManager)
            .onDisappear {
                // Quit the app when the main window is closed
                performCleanupTask()
                NSApplication.shared.terminate(nil)
            }
        }
        .commands {
            SidebarCommands()

            ToggleCommands()
        }

        Window("ZoomcgImage", id: "zoom-window-cgImage") {
            ZoomableCSImageView(cgImage: cgImage)
                .onAppear {
                    zoomCGImageWindowFocused = true
                }
                .onDisappear {
                    zoomCGImageWindowFocused = false
                }
        }
        .defaultPosition(.center)
        .defaultSize(width: 800, height: 600)

        // If there is a extracted JPG image
        Window("ZoomnsImage", id: "zoom-window-nsImage") {
            ZoomableNSImageView(nsImage: nsImage)
                .onAppear {
                    zoomNSImageWindowFocused = true
                }
                .onDisappear {
                    zoomNSImageWindowFocused = false
                }
        }
        .defaultPosition(.center)
        .defaultSize(width: 800, height: 600)
    }

    private func performCleanupTask() {
        Logger.process.debugMessageOnly("PhotoCullingApp: performCleanupTask(), shutting down, doing clean up")
    }
}

enum WindowIdentifier: String {
    case main = "main-window"
    case zoomcgImage = "zoom-window-cgImage"
    case zoomnsImage = "zoom-window-nsImage"
}

enum SupportedFileType: String, CaseIterable {
    case arw
    case tiff, tif
    case jpeg, jpg

    var extensions: [String] {
        switch self {
        case .arw: return ["arw"]
        case .tiff: return ["tiff"]
        case .jpeg: return ["jpeg"]
        case .tif: return ["tif"]
        case .jpg: return ["jpg"]
        }
    }
}

enum ThumbnailSize {
    static let grid = 100
    static let preview = 1024
    static let fullSize = 8700
}
