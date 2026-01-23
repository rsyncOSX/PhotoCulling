//
//  ProcessHandlers.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 22/01/2026.
//

/*
struct FileHandlers: Sendable {
    
    let fileHandler: @MainActor @Sendable (Int) -> Void
    let maxfilesHandler: @MainActor @Sendable (Int) -> Void

    init(
        fileHandler: @escaping @Sendable (Int) -> Void,
        maxfilesHandler: @escaping @Sendable (Int) -> Void
    ) {
        self.fileHandler = fileHandler
        self.maxfilesHandler = maxfilesHandler
    }
}
*/
struct FileHandlers {
    // Add @MainActor here!
    let fileHandler: @MainActor @Sendable (Int) -> Void
    let maxfilesHandler: @MainActor @Sendable (Int) -> Void
}
