//
//  ProcessHandlers.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 22/01/2026.
//

public struct ProcessHandlers: Sendable {
    
    public let fileHandler: @Sendable (Int) -> Void
    public let maxfilesHandler: @Sendable (Int) -> Void

    public init(
        fileHandler: @escaping @Sendable (Int) -> Void,
        maxfilesHandler: @escaping @Sendable (Int) -> Void
    ) {
        self.fileHandler = fileHandler
        self.maxfilesHandler = maxfilesHandler
    }
}
