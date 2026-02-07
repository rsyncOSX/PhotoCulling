//
//  CacheDelegate.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 07/02/2026.
//

import AppKit
import Foundation
import OSLog

/// Delegate to track NSCache evictions for monitoring memory pressure
final class CacheDelegate: NSObject, NSCacheDelegate, @unchecked Sendable {
    nonisolated static let shared = CacheDelegate()

    override nonisolated init() {
        super.init()
    }

    nonisolated func cache(_: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // The cast still works exactly the same way
        if let image = obj as? NSImage {
            Logger.process.debugMessageOnly("Evicted image: \(image)")
        }
    }
}
