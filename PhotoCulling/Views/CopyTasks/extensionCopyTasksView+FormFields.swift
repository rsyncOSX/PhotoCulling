//
//  extensionCopyTasksView+FormFields.swift
//
//  Created by Thomas Evensen on 13/12/2025.
//
import OSLog
import SwiftUI

// MARK: - Form Field Sections

extension CopyTasksView {
    var sourceanddestination: some View {
        Section("Source and Destination") {
            catalogField(catalog: $sourcecatalog,
                         placeholder: "Add Source folder - required",
                         selectedValue: sourcecatalog)

            catalogField(catalog: $destinationcatalog,
                         placeholder: "Add Destination folder - required",
                         selectedValue: destinationcatalog,
                         showErrorBorder: !sourcecatalog.isEmpty && destinationcatalog.isEmpty ||
                             sourcecatalog.isEmpty && !destinationcatalog.isEmpty)
        }
    }

    func catalogField(catalog: Binding<String>,
                      placeholder: String,
                      selectedValue: String?,
                      showErrorBorder: Bool = false) -> some View
    {
        HStack {
            if sourcecatalog.isEmpty {
                EditValueScheme(300, placeholder, catalog)
                    .onAppear { if let value = selectedValue { catalog.wrappedValue = value } }
                    .border(showErrorBorder ? Color.red : Color.clear, width: 2)
            } else {
                EditValueScheme(300, nil, catalog)
                    .onAppear { if let value = selectedValue { catalog.wrappedValue = value } }
                    .border(showErrorBorder ? Color.red : Color.clear, width: 2)
            }

            OpencatalogView(selecteditem: catalog, catalogs: true)
        }
    }
}
