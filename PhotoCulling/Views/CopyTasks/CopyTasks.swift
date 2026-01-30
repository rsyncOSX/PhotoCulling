//
//  CopyTasks.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 11/12/2023.
//

import OSLog
import SwiftUI

enum AddConfigurationField: Hashable {
    case sourcecatalogField
    case destinationcatalogField
}

enum TypeofTask: String, CaseIterable, Identifiable, CustomStringConvertible {
    case synchronize

    var id: String {
        rawValue
    }

    var description: String {
        rawValue.localizedLowercase
    }
}

struct CopyTasks: View {
    @State var newdata = ObservableCopyTasks()

    var body: some View {
        sourceanddestination
    }
}
