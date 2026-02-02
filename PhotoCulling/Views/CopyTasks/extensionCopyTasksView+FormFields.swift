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
                      showErrorBorder: Bool = false) -> some View {
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

// MARK: - Copy Options Section Component

struct CopyOptionsSection: View {
    @Binding var copytaggedfiles: Bool
    @Binding var copyratedfiles: Int
    @Binding var dryrun: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copy Options")
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                // Copy tagged files toggle
                ToggleViewDefault(text: "Copy tagged files?",
                                  binding: $copytaggedfiles)

                // Dry run toggle
                ToggleViewDefault(text: "Dry run?",
                                  binding: $dryrun)

                // Rating picker (only shown when not copying tagged files)
                RatingPickerSection(rating: $copyratedfiles)
                    .disabled(copytaggedfiles)
            }
        }
    }
}

// MARK: - Rating Picker Component

struct RatingPickerSection: View {
    @Binding var rating: Int

    var body: some View {
        VStack {
            Label("Minimum Rating", systemImage: "star.fill")
                .foregroundColor(.secondary)

            Spacer()

            Picker("Rating", selection: $rating) {
                ForEach(0 ... 5, id: \.self) { number in
                    HStack {
                        ForEach(0 ..< number, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption)
                        }
                        Text("\(number)")
                    }
                    .tag(number)
                }
            }
            .pickerStyle(DefaultPickerStyle())
            .frame(width: 120)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Action Buttons Component

struct CopyActionButtonsSection: View {
    let dismiss: DismissAction
    let onCopyTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ConditionalGlassButton(
                systemImage: "arrowshape.right.fill",
                text: "Start Copy",
                helpText: "Start copying files"
            ) {
                onCopyTapped()
            }

            Spacer()

            Button("Close", role: .close) {
                dismiss()
            }
            .buttonStyle(RefinedGlassButtonStyle())
        }
    }
}
