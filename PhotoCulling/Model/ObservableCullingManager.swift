import Foundation
import Observation

@Observable
class ObservableCullingManager {
    // Standard property - Observation handles this automatically
    var selectedFiles: Set<String> = []

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

    func toggleSelection(filename: String) {
        if selectedFiles.contains(filename) {
            selectedFiles.remove(filename)
        } else {
            selectedFiles.insert(filename)
        }
        saveToJSON()
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
        do {
            let data = try Data(contentsOf: savePath)
            selectedFiles = try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            print("Load failed: \(error)")
        }
    }
}
