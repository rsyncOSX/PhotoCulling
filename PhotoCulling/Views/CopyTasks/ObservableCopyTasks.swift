//
//  ObservableCopyTasks.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 03/06/2021.
//

import Foundation
import Observation
import OSLog

enum TrailingSlash: String, CaseIterable, Identifiable, CustomStringConvertible {
    case add

    var id: String {
        rawValue
    }

    var description: String {
        rawValue.localizedCapitalized.replacingOccurrences(of: "_", with: " ")
    }
}

@Observable @MainActor
final class ObservableCopyTasks {
    var trailingslashoptions = TrailingSlash.add
    var selectedrsynccommand = TypeofTask.synchronize

    var sourcecatalog: String = ""
    var destinationcatalog: String = ""
}
