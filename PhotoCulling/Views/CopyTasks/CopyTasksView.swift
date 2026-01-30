//
//  CopyTasksView.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 11/12/2023.
//

import OSLog
import SwiftUI

struct CopyTasksView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSource: FolderSource?

    @State var sourcecatalog: String = ""
    @State var destinationcatalog: String = ""

    @State var showingAlert: Bool = false
    @State var progress: Double = 0
    @State var max: Double = 0

    var body: some View {
        VStack {
            sourceanddestination

            HStack {
                ConditionalGlassButton(
                    systemImage: "arrowshape.right.fill",
                    text: "",
                    helpText: "Start copying files"
                ) {
                    showingAlert = true
                }

                Spacer()

                Button("Close", role: .close) {
                    dismiss()
                }
                .buttonStyle(RefinedGlassButtonStyle())
            }
            .padding()
        }
        .padding()
        .frame(
            minWidth: 600,
            idealWidth: 600,
            minHeight: 400,
            idealHeight: 400,
            alignment: .init(horizontal: .center, vertical: .center)
        )
        .task(id: selectedSource) {
            guard let selectedSource else { return }
            sourcecatalog = selectedSource.url.path
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Copy ARW files"),
                message: Text("Are you sure you want to copy all tagged ARW files?"),
                primaryButton: .destructive(Text("Copy")) {
                    var configuration = SynchronizeConfiguration()
                    configuration.localCatalog = sourcecatalog
                    configuration.offsiteCatalog = destinationcatalog
                    handleTrailingSlash(newconfig: &configuration)

                    let copytask = ExecuteCopyFiles(
                        fileHandler: fileHandler,
                        processTermination: processtermination
                    )
                    copytask.startcopyfiles(config: configuration)
                },
                secondaryButton: .cancel()
            )
        }
    }

    func fileHandler(_ update: Int) {
        progress = Double(update)
        print("\(update)")
    }

    func processtermination(output: [String]?, _: Int?) {
        print(output)
    }

    func maxfilesHandler(_ maxfiles: Int) {
        max = Double(maxfiles)
    }

    private func handleTrailingSlash(newconfig: inout SynchronizeConfiguration) {
        newconfig.localCatalog = newconfig.localCatalog.hasSuffix("/") ?
            newconfig.localCatalog : newconfig.localCatalog + "/"
        newconfig.offsiteCatalog = newconfig.offsiteCatalog.hasSuffix("/") ?
            newconfig.offsiteCatalog : newconfig.offsiteCatalog + "/"
    }
}
