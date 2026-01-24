//
//  DiscardableThumbnail.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 23/01/2026.
//
import AppKit
import Foundation
import os

final class DiscardableThumbnail: NSObject, NSDiscardableContent, @unchecked Sendable {
    let image: NSImage
    let cost: Int
    private let state = OSAllocatedUnfairLock(initialState: (isDiscarded: false, accessCount: 0))

    nonisolated init(image: NSImage) {
        self.image = image

        // IMPROVEMENT: Calculate cost using actual pixel dimensions, not logical points.
        // This ensures NSCache knows the true RAM footprint of your 2560px images.
        let width: Int
        let height: Int

        if let rep = image.representations.first {
            width = rep.pixelsWide
            height = rep.pixelsHigh
        } else {
            // Fallback to logical size if representations are missing
            width = Int(image.size.width)
            height = Int(image.size.height)
        }

        // 4 bytes per pixel (RGBA)
        cost = width * height * 4

        super.init()
    }

    nonisolated func beginContentAccess() -> Bool {
        state.withLock {
            if $0.isDiscarded { return false }
            $0.accessCount += 1
            return true
        }
    }

    nonisolated func endContentAccess() {
        state.withLock { $0.accessCount = max(0, $0.accessCount - 1) }
    }

    nonisolated func discardContentIfPossible() {
        state.withLock { if $0.accessCount == 0 { $0.isDiscarded = true } }
    }

    nonisolated func isContentDiscarded() -> Bool {
        state.withLock { $0.isDiscarded }
    }
}
