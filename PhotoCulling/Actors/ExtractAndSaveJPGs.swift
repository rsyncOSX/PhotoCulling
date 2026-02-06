//
//  ExtractAndSaveJPGs.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 26/01/2026.
//

import Foundation
import OSLog

actor ExtractAndSaveJPGs {
    // Track the current preload task so we can cancel it

    private var extractJPEGSTask: Task<Int, Never>?
    private var successCount = 0

    private var fileHandlers: FileHandlers?

    func setFileHandlers(_ fileHandlers: FileHandlers) {
        self.fileHandlers = fileHandlers
    }

    @discardableResult
    func extractAndSaveAlljpgs(from catalogURL: URL, fullSize: Bool = false) async -> Int {
        cancelExtractJPGSTask()

        let task = Task {
            successCount = 0
            let urls = await DiscoverFiles().discoverFiles(at: catalogURL, recursive: false)

            await fileHandlers?.maxfilesHandler(urls.count)

            return await withThrowingTaskGroup(of: Void.self) { group in
                let maxConcurrent = ProcessInfo.processInfo.activeProcessorCount * 2 // Be a bit more aggressive

                for (index, url) in urls.enumerated() {
                    // Check for cancellation at the start of every loop
                    if Task.isCancelled {
                        group.cancelAll() // FIX #2: Stop all running tasks
                        break
                    }

                    if index >= maxConcurrent {
                        try? await group.next()
                    }

                    group.addTask {
                        if let cgImage = await ExtractEmbeddedPreview().extractEmbeddedPreview(
                            from: url,
                            fullSize: fullSize
                        ) {
                            await ExtractEmbeddedPreview().save(image: cgImage, originalURL: url)

                            let newCount = await self.incrementAndGetCount()
                            await self.fileHandlers?.fileHandler(newCount)
                        }
                    }
                }

                // Wait for remaining tasks to finish (or be cancelled)
                try? await group.waitForAll()
                return successCount
            }
        }

        extractJPEGSTask = task
        return await task.value
    }

    private func cancelExtractJPGSTask() {
        extractJPEGSTask?.cancel()
        extractJPEGSTask = nil
        Logger.process.debugMessageOnly("ExtractAndSaveAlljpgs: Preload Cancelled")
    }

    private func incrementAndGetCount() -> Int {
        successCount += 1
        return successCount
    }
}
