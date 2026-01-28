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

    var body: some Scene {
        Window("Photo Culling", id: "main-window") {
            SidebarPhotoCullingView(nsImage: $nsImage, cgImage: $cgImage)
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

        Window("Zoom", id: "zoom-window-arw") {
            ZoomableImageViewARW(cgImage: cgImage)
        }
        .defaultPosition(.center)
        .defaultSize(width: 800, height: 600)
    }

    private func performCleanupTask() {
        Logger.process.debugMessageOnly("PhotoCullingApp: performCleanupTask(), shutting down, doing clean up")
    }
}
