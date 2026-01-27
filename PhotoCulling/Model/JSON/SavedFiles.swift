//
//  SavedFiles.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 27/01/2026.
//

//
//  LogRecords.swift
//  RsyncUI
//

import Foundation

struct SavedFiles: Identifiable, Codable {
    var id = UUID()
    var catalog: URL?
    var dateStart: String?
    var filerecords: [FileRecord]?

    /// Used when reading JSON data from store
    init(_ data: DecodeSavedFiles) {
        dateStart = data.dateStart ?? ""
        catalog = data.catalog
        filerecords = data.filerecords?.map { record in
            FileRecord(
                fileName: record.fileName,
                dateTagged: record.dateTagged,
                dateCopied: record.dateCopied
            )
        }
    }

    /// Create an empty record with no values
    init() {
        dateStart = nil
    }
}

extension SavedFiles: Hashable, Equatable {
    static func == (lhs: SavedFiles, rhs: SavedFiles) -> Bool {
        lhs.dateStart == rhs.dateStart &&
            lhs.catalog == rhs.catalog
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(dateStart)
        hasher.combine(catalog)
    }
}

struct FileRecord: Identifiable, Codable {
    var id = UUID()
    var fileName: String?
    var dateTagged: String?
    var dateCopied: String?
    var date: Date {
        dateTagged?.en_date_from_string() ?? Date()
    }
}

extension FileRecord: Hashable, Equatable {
    static func == (lhs: FileRecord, rhs: FileRecord) -> Bool {
        lhs.fileName == rhs.fileName &&
            lhs.dateTagged == rhs.dateTagged &&
            lhs.dateCopied == rhs.dateCopied
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(fileName)
        hasher.combine(dateTagged)
        hasher.combine(dateCopied)
    }
}
