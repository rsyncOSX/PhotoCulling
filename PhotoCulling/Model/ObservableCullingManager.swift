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

    init() {
        loadFromJSON()
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

        // Update numberofPreselectedFiles with catalog count
        if let catalog = catalog {
            let catalogPath = catalog.path
            let count = countSelectedFiles(in: catalog)

            // Remove old entry for this catalog if it exists
            removeCatalogEntry(forPath: catalogPath)

            // Add new entry with updated count
            if count > 0 {
                numberofPreselectedFiles.insert(StringIntPair(string: catalogPath, int: count))
            }
        }

        saveToJSON()
    }

    func countSelectedFiles(in catalog: URL) -> Int {
        let catalogPath = catalog.path
        return selectedFiles.filter { filename in
            filename.hasPrefix(catalogPath)
        }.count
    }

    func saveToJSON() {
        do {
            let data = try JSONEncoder().encode(selectedFiles)
            try data.write(to: savePath, options: [.atomic])
        } catch {
            print("Save failed: \(error)")
        }
    }

    func loadFromJSON() {
        guard FileManager.default.fileExists(atPath: savePath.path) else { return }
        Logger.process.debugMessageOnly("ObservableCullingManager: loading stored filenames from JSON")
        do {
            let data = try Data(contentsOf: savePath)
            selectedFiles = try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            print("Load failed: \(error)")
        }
    }
}
