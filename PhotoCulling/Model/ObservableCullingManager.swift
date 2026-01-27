import Foundation
import Observation
import OSLog

@Observable
final class ObservableCullingManager {
    // New saved filenames.

    var savedFiles = [SavedFiles]()

    func loadSavedFiles() {
        if let readjson = ReadSavedFilesJSON().readjsonfilesavedfiles() {
            savedFiles = readjson
        }
    }

    func toggleSelectionSavedFiles(in fileurl: URL, taggedfilename: String) {
        let newrecord = FileRecord(
            fileName: taggedfilename,
            dateTagged: Date().en_string_from_date(),
            dateCopied: nil
        )

        let arwcatalog = fileurl.deletingLastPathComponent()

        if savedFiles.isEmpty {
            let savedfiles = SavedFiles(
                catalog: arwcatalog,
                dateStart: Date().en_string_from_date(),
                filerecord: newrecord
            )
            savedFiles.append(savedfiles)
        } else {
            // Check if arw catalog exists in data structure
            if let index = savedFiles.firstIndex(where: { $0.catalog == arwcatalog }) {
                savedFiles[index].filerecords?.append(newrecord)
            } else {
                // If not append a new one
                let savedfiles = SavedFiles(
                    catalog: arwcatalog,
                    dateStart: Date().en_string_from_date(),
                    filerecord: newrecord
                )
                savedFiles.append(savedfiles)
            }
        }

        WriteSavedFilesJSON(savedFiles)
    }

    // Standard property - Observation handles this automatically
    var selectedFiles: Set<String> = []
    private let fileName = "selections.json"

    /// We don't want the UI to "track" the file path, so we ignore it
    @ObservationIgnored
    private var savePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    func toggleSelection(in catalog: URL?, filename: String) {
        if selectedFiles.contains(filename) {
            Logger.process.debugMessageOnly("ObservableCullingManager: removing \(filename)")
            selectedFiles.remove(filename)
        } else {
            Logger.process.debugMessageOnly("ObservableCullingManager: inserting \(filename)")
            selectedFiles.insert(filename)
        }

        saveToJSON()

        if let catalog {
            toggleSelectionSavedFiles(in: catalog, taggedfilename: filename)
        }
    }

    func countSelectedFiles(in catalog: URL) -> Int {
        selectedFiles.reduce(into: 0) { count, filename in
            let fileURL = catalog.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                count += 1
            }
        }
    }

    func saveToJSON() {
        do {
            let data = try JSONEncoder().encode(selectedFiles)
            try data.write(to: savePath, options: [.atomic])
        } catch {
            Logger.process.warning("Save failed: \(error)")
        }
    }

    func loadFromJSON(in _: URL) {
        guard FileManager.default.fileExists(atPath: savePath.path) else { return }
        do {
            let data = try Data(contentsOf: savePath)
            selectedFiles = try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            Logger.process.warning("Load failed: \(error)")
        }

        loadSavedFiles()
    }
}
