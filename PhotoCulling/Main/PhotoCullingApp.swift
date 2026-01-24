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

    var body: some Scene {
        Window("Photo Culling", id: "main-window") {
            SidebarPhotoCullingView(nsImage: $nsImage)
                .onDisappear {
                    // Quit the app when the main window is closed
                    performCleanupTask()
                    NSApplication.shared.terminate(nil)
                }
        }

        Window("Zoom", id: "zoom-window") {
            ZoomableImageView(nsImage: nsImage)
        }
        .defaultPosition(.center)
        .defaultSize(width: 600, height: 400)
    }

    private func performCleanupTask() {
        Logger.process.debugMessageOnly("PhotoCullingApp: performCleanupTask(), shutting down, doing clean up")
    }
}
