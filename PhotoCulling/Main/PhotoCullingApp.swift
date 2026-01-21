//
//  PhotoCullingApp.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 19/01/2026.
//

import OSLog
import SwiftUI

@main
struct PhotoCullingApp: App {
    var body: some Scene {
        Window("Photo Culling", id: "main-window") {
            SidebarPhotoCullingView()
        }
    }
}
