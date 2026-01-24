//
//  ScanFiles.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 20/01/2026.
//

import Foundation
import OSLog

actor ScanFiles {
    @concurrent
    nonisolated func scanFiles(url: URL) async -> [FileItem] {
        Logger.process.debugThreadOnly("func scanFiles()")
        // Essential for Sandbox apps
        guard url.startAccessingSecurityScopedResource() else { return [] }

        let keys: [URLResourceKey] = [
            .nameKey,
            .fileSizeKey,
            .contentTypeKey,
            .contentModificationDateKey
        ]
        let manager = FileManager.default

        do {
            let contents = try manager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            )

            let scannedFiles = contents.compactMap { fileURL -> FileItem? in
                let res = try? fileURL.resourceValues(forKeys: Set(keys))
                return FileItem(
                    url: fileURL,
                    name: res?.name ?? fileURL.lastPathComponent,
                    size: Int64(res?.fileSize ?? 0),
                    type: res?.contentType?.localizedDescription ?? "File",
                    dateModified: res?.contentModificationDate ?? Date()
                )
            }

            return scannedFiles
        } catch {
            Logger.process.warning("Scan Error: \(error)")
        }

        // Note: In a real app, you'd manage the scope lifecycle more carefully
        // url.stopAccessingSecurityScopedResource()

        return []
    }

    @concurrent
    nonisolated func sortFiles<C: SortComparator<FileItem>>(
        _ files: [FileItem],
        by sortOrder: [C],
        searchText: String
    ) async -> [FileItem] {
        Logger.process.debugThreadOnly("func sortFiles()")
        let sorted = files.sorted(using: sortOrder)
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
}
