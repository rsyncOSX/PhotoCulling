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
        cost = Int(image.size.width * image.size.height * 4)
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

/*
 
 Should be this code
 
 import AppKit

 // 1. Mark final to ensure strict dispatch safety and prevent inheritance issues
 final class DiscardableThumbnail: NSDiscardableContent {
     let image: NSImage
     
     // 2. Make 'cost' a stored property (calculated once in init) instead of a computed property.
     // This prevents isolation errors when NSCache tries to read it later from its own internal thread.
     let cost: Int
     
     private var accessCounter = 0

     init(image: NSImage) {
         self.image = image
         
         // Calculate cost right now while we are on the Actor
         if let rep = image.representations.first {
             // Actual pixel dimensions * 4 bytes (RGBA)
             self.cost = rep.pixelsWide * rep.pixelsHigh * 4
         } else {
             // Fallback if representations aren't loaded yet (use logical size)
             self.cost = Int(image.size.width * image.size.height * 4)
         }
     }
     
     // MARK: - NSDiscardableContent
     
     func beginContentAccess() -> Bool {
         if accessCounter == 0 {
             // If you were actually discarding the underlying image data to save RAM,
             // you would reload it here.
         }
         accessCounter += 1
         return true
     }
     
     func endContentAccess() {
         if accessCounter > 0 {
             accessCounter -= 1
         }
     }
     
     func discardContentIfPossible() {
         // Implementation depends on your strategy.
         // Since NSCache evicts the whole object based on cost/limits,
         // we don't strictly need to nil out the image here,
         // but doing so ensures the bitmap memory is freed instantly.
         if accessCounter == 0 {
             // image = nil // Optional: if you want to aggressively free memory immediately
         }
     }
     
     var isContentDiscarded: Bool {
         return accessCounter == 0 // Placeholder logic
     }
 }
 */
