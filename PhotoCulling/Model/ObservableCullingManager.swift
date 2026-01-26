import Foundation
import Observation
import OSLog

struct StringIntPair: Hashable {
    let string: String
    let int: Int
}

@Observable
final class ObservableCullingManager {
    // Standard property - Observation handles this automatically
    var selectedFiles: Set<String> = []
    var numberofPreselectedFiles: Set<StringIntPair> = []

    private let fileName = "selections.json"

    // We don't want the UI to "track" the file path, so we ignore it
    @ObservationIgnored
    private var savePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    init(catalog: URL?) {
        if let catalog {
            loadFromJSON(in: catalog)
        }
    }

    private func removeCatalogEntry(forPath catalogPath: String) {
        for item in numberofPreselectedFiles where item.string == catalogPath {
            numberofPreselectedFiles.remove(item)
        }
    }

    func toggleSelection(in catalog: URL?, filename: String) {
        if selectedFiles.contains(filename) {
            Logger.process.debugMessageOnly("ObservableCullingManager: removing \(filename)")
            selectedFiles.remove(filename)
        } else {
            Logger.process.debugMessageOnly("ObservableCullingManager: inserting \(filename)")
            selectedFiles.insert(filename)
        }
/*
        // Update numberofPreselectedFiles with catalog count
        if let catalog = catalog {
            let folderURL = catalog.deletingLastPathComponent()
            let catalogPath = folderURL.absoluteString
            let count = countSelectedFiles(in: folderURL)

            // Remove old entry for this catalog if it exists
            removeCatalogEntry(forPath: catalogPath)

            // Add new entry with updated count
            if count > 0 {
                numberofPreselectedFiles.insert(StringIntPair(string: catalogPath, int: count))
            }
        }
*/
        saveToJSON()
    }

    func countSelectedFiles(in catalog: URL) -> Int {
        selectedFiles.reduce(into: 0) { count, filename in
            let fileURL = catalog.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                count += 1
            }
        }
    }
    
    func countSelectedFilesLabel(in catalog: URL) -> String {
        let count = selectedFiles.reduce(into: 0) { count, filename in
            let fileURL = catalog.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                count += 1
            }
        }
        return "\(count)"
    }

    func saveToJSON() {
        do {
            let data = try JSONEncoder().encode(selectedFiles)
            try data.write(to: savePath, options: [.atomic])
        } catch {
            Logger.process.warning("Save failed: \(error)")
        }
    }

    func loadFromJSON(in catalog: URL) {
        guard FileManager.default.fileExists(atPath: savePath.path) else { return }
        do {
            let data = try Data(contentsOf: savePath)
            selectedFiles = try JSONDecoder().decode(Set<String>.self, from: data)
            let count = countSelectedFiles(in: catalog)

            if count > 0 {
                Logger.process.debugMessageOnly("ObservableCullingManager: loaded \(count) filenames from JSON")
                numberofPreselectedFiles.insert(StringIntPair(string: catalog.absoluteString, int: count))
            }
        } catch {
            Logger.process.warning("Load failed: \(error)")
        }
    }
}
