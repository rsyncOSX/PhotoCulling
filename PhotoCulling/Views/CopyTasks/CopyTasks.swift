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
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSource: FolderSource?
    
    @State var newdata = ObservableCopyTasks()

    var body: some View {
        VStack {
            
            sourceanddestination
            
            Button("Close", role: .close) {
                dismiss()
            }
            .buttonStyle(RefinedGlassButtonStyle())
        }
        .padding()
        .frame(minWidth: 600, idealWidth: 600, minHeight: 400, idealHeight: 400, alignment: .init(horizontal: .center, vertical: .center))
        .task(id: selectedSource) {
            guard let selectedSource else { return }
            newdata.sourcecatalog = selectedSource.url.path
        }
        
    }
}
