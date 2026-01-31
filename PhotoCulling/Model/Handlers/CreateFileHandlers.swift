//
//  CreateFileHandlers.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 23/01/2026.
//

import Foundation

struct CreateFileHandlers {
    func createFileHandlers(
        fileHandler: @escaping @MainActor @Sendable (Int) -> Void,
        maxfilesHandler: @escaping @MainActor @Sendable (Int) -> Void
    ) -> FileHandlers {
        FileHandlers(
            fileHandler: fileHandler,
            maxfilesHandler: maxfilesHandler
        )
    }
}
