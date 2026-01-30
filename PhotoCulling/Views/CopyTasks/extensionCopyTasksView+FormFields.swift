//
//  extensionCopyTasksView+FormFields.swift
//
//  Created by Thomas Evensen on 13/12/2025.
//
import OSLog
import SwiftUI

// MARK: - Form Field Sections

extension CopyTasks {
    var sourceanddestination: some View {
        Section("Source and Destination") {
            catalogField(catalog: $newdata.sourcecatalog,
                         placeholder: "Add Source folder - required",
                         selectedValue: newdata.sourcecatalog)

            catalogField(catalog: $newdata.destinationcatalog,
                         placeholder: "Add Destination folder - required",
                         selectedValue: newdata.destinationcatalog,
                         showErrorBorder: !newdata.sourcecatalog.isEmpty && newdata.destinationcatalog.isEmpty ||
                             newdata.sourcecatalog.isEmpty && !newdata.destinationcatalog.isEmpty)
        }
    }

    func catalogField(catalog: Binding<String>,
                      placeholder: String,
                      selectedValue: String?,
                      showErrorBorder: Bool = false) -> some View {
        HStack {
            if newdata.sourcecatalog.isEmpty {
                EditValueScheme(400, placeholder, catalog)
                    .onAppear { if let value = selectedValue { catalog.wrappedValue = value } }
                    .border(showErrorBorder ? Color.red : Color.clear, width: 2)
            } else {
                EditValueScheme(400, nil, catalog)
                    .onAppear { if let value = selectedValue { catalog.wrappedValue = value } }
                    .border(showErrorBorder ? Color.red : Color.clear, width: 2)
            }

            OpencatalogView(selecteditem: catalog, catalogs: true)
        }
    }

    var trailingslash: some View {
        Picker("Trailing /", selection: $newdata.trailingslashoptions) {
            ForEach(TrailingSlash.allCases) { Text($0.description).tag($0) }
        }
        .pickerStyle(DefaultPickerStyle()).frame(width: 180)
        .onChange(of: newdata.trailingslashoptions) {
            UserDefaults.standard.set(newdata.trailingslashoptions.rawValue, forKey: "trailingslashoptions")
        }
    }

    var pickerselecttypeoftask: some View {
        Picker("Action", selection: $newdata.selectedrsynccommand) {
            ForEach(TypeofTask.allCases) { Text($0.description).tag($0) }
        }
        .pickerStyle(DefaultPickerStyle()).frame(width: 180)
        .onChange(of: newdata.selectedrsynccommand) {
            UserDefaults.standard.set(newdata.selectedrsynccommand.rawValue, forKey: "selectedrsynccommand")
        }
    }
}
