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
    @Bindable var viewModel: SidebarPhotoCullingViewModel

    @Binding var selectedSource: FolderSource?
    @Binding var remotedatanumbers: RemoteDataNumbers?
    @Binding var sheetType: SheetType?
    @Binding var showcopytask: Bool

    @State var sourcecatalog: String = ""
    @State var destinationcatalog: String = ""

    @State var showingAlert: Bool = false
    @State var progress: Double = 0
    @State var max: Double = 0

    @State private var executionManager: ExecuteCopyFiles?
    @State private var showprogressview = false

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
                    executeCopyFiles()
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: executionManager?.progress) { _, newValue in
            if let newValue {
                progress = newValue
            }
        }
    }

    private func handleTrailingSlash(newconfig: inout SynchronizeConfiguration) {
        newconfig.localCatalog = newconfig.localCatalog.hasSuffix("/") ?
            newconfig.localCatalog : newconfig.localCatalog + "/"
        newconfig.offsiteCatalog = newconfig.offsiteCatalog.hasSuffix("/") ?
            newconfig.offsiteCatalog : newconfig.offsiteCatalog + "/"
    }

    func executeCopyFiles() {
        let dryrun = true
        var configuration = SynchronizeConfiguration()
        configuration.localCatalog = sourcecatalog
        configuration.offsiteCatalog = destinationcatalog

        handleTrailingSlash(newconfig: &configuration)

        executionManager = ExecuteCopyFiles(
            configuration: configuration,
            dryrun: dryrun,
            sidebarPhotoCullingViewModel: viewModel
        )

        executionManager?.onProgressUpdate = { newProgress in
            Task { @MainActor in
                progress = newProgress
            }
        }

        executionManager?.onCompletion = { result in
            Task { @MainActor in
                handleCompletion(result: result)
            }
        }

        executionManager?.startcopyfiles()
    }

    private func handleCompletion(result: CopyDataResult) {
        var configuration = SynchronizeConfiguration()
        configuration.localCatalog = sourcecatalog
        configuration.offsiteCatalog = destinationcatalog

        // showprogressview = false

        max = Double(result.linesCount)

        remotedatanumbers = RemoteDataNumbers(
            stringoutputfromrsync: result.output,
            config: configuration
        )

        // Set the output for view if available
        if let viewOutput = result.viewOutput {
            var output = viewOutput
            let numberOfRowsToRemove = 14

            if output.count >= numberOfRowsToRemove {
                output.removeLast(numberOfRowsToRemove)
            } else {
                // Handle the case where there are fewer than 16 rows
                // (Optionally clear the array or do nothing)
                output.removeAll()
            }
            remotedatanumbers?.outputfromrsync = output
        }

        // Clean up
        executionManager = nil

        sheetType = .detailsview
        showcopytask = true
    }
}

// rsync -av --include-from=my_list.txt --exclude='*' /path/to/source/ /path/to/destination/
