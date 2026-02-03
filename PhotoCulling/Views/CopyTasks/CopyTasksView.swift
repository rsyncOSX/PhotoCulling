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

    @State var dryrun: Bool = true
    @State var copytaggedfiles: Bool = true
    @State var copyratedfiles: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            // Header with options
            CopyOptionsSection(
                copytaggedfiles: $copytaggedfiles,
                copyratedfiles: $copyratedfiles,
                dryrun: $dryrun
            )

            Divider()

            // Source and destination catalogs
            sourceanddestination

            Spacer()

            // Action buttons
            CopyActionButtonsSection(
                dismiss: dismiss,
                onCopyTapped: {
                    guard sourcecatalog.isEmpty == false, destinationcatalog.isEmpty == false else {
                        return
                    }
                    showingAlert = true
                }
            )
        }
        .padding()
        .frame(width: 650, height: 500, alignment: .init(horizontal: .center, vertical: .center))
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

    // MARK: - Private Methods

    private func handleTrailingSlash(newconfig: inout SynchronizeConfiguration) {
        newconfig.localCatalog = newconfig.localCatalog.hasSuffix("/") ?
            newconfig.localCatalog : newconfig.localCatalog + "/"
        newconfig.offsiteCatalog = newconfig.offsiteCatalog.hasSuffix("/") ?
            newconfig.offsiteCatalog : newconfig.offsiteCatalog + "/"
    }

    private func executeCopyFiles() {
        var configuration = SynchronizeConfiguration()
        configuration.localCatalog = sourcecatalog
        configuration.offsiteCatalog = destinationcatalog

        handleTrailingSlash(newconfig: &configuration)

        executionManager = ExecuteCopyFiles(
            configuration: configuration,
            dryrun: dryrun,
            rating: copyratedfiles,
            copytaggedfiles: copytaggedfiles,
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

        max = Double(result.linesCount)

        remotedatanumbers = RemoteDataNumbers(
            stringoutputfromrsync: result.output,
            config: configuration
        )

        // Set the output for view if available
        if let viewOutput = result.viewOutput {
            remotedatanumbers?.outputfromrsync = viewOutput
        }

        // Clean up
        executionManager = nil

        sheetType = .detailsview
        showcopytask = true
    }
}
