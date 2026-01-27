import Foundation
import Observation
import OSLog

@Observable
final class ObservableCullingManager {
    var savedFiles = [SavedFiles]()

    func loadSavedFiles() {
        if let readjson = ReadSavedFilesJSON().readjsonfilesavedfiles() {
            savedFiles = readjson
        }
    }

    func resetSavedFiles(in catalog: URL) {
        if let index = savedFiles.firstIndex(where: { $0.catalog == catalog }) {
            savedFiles[index].filerecords = nil
            // Save updated
            WriteSavedFilesJSON(savedFiles)
        }
    }

    func toggleSelectionSavedFiles(in fileurl: URL, toggledfilename: String) {
        let newrecord = FileRecord(
            fileName: toggledfilename,
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
                if savedFiles[index].filerecords == nil {
                    savedFiles[index].filerecords = [newrecord]
                } else {
                    savedFiles[index].filerecords?.append(newrecord)
                }
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

    func toggleSelection(in catalog: URL?, filename: String) {
        if let catalog {
            toggleSelectionSavedFiles(in: catalog, toggledfilename: filename)
        }
    }

    func countSelectedFiles(in catalog: URL) -> Int {
        if let index = savedFiles.firstIndex(where: { $0.catalog == catalog }) {
            if let filerecords = savedFiles[index].filerecords {
                return filerecords.count
            }
        }
        return 0
    }

    func loadFromJSON() {
        loadSavedFiles()
    }
}
