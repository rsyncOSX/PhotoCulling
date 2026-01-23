//
//  FileHandlers.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 22/01/2026.
//

struct FileHandlers {
    // Add @MainActor here!
    let fileHandler: @MainActor @Sendable (Int) -> Void
    let maxfilesHandler: @MainActor @Sendable (Int) -> Void
}
