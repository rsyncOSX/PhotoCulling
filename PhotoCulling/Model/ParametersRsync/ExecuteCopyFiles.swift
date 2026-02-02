//
//  ExecuteCopyFiles.swift
//  Created by Thomas Evensen on 10/06/2025.
//

import Foundation
import OSLog
import RsyncProcessStreaming

struct CopyDataResult {
    let output: [String]?
    let viewOutput: [RsyncOutputData]?
    let linesCount: Int
}

struct RsyncOutputData: Identifiable, Equatable, Hashable {
    let id = UUID()
    var record: String
}

@Observable @MainActor
final class ExecuteCopyFiles {
    weak var sidebarPhotoCullingViewModel: SidebarPhotoCullingViewModel?

    let config: SynchronizeConfiguration
    let dryrun: Bool
    // Streaming references
    private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?
    /// State
    var progress: Double = 0
    // var remotedatanumbers: RemoteDataNumbers?

    // Callbacks
    var onProgressUpdate: ((Double) -> Void)?
    var onCompletion: ((CopyDataResult) -> Void)?

    func startcopyfiles() {
        let arguments = ArgumentsSynchronize(config: config).argumentsSynchronize(
            dryRun: dryrun
        )

        setupStreamingHandlers()

        guard let arguments, let streamingHandlers else { return }

        let filelist = sidebarPhotoCullingViewModel?.extractTaggedfilenames()
            .map { URL(string: $0)?.path ?? $0 } ?? []
        let filelist2 = sidebarPhotoCullingViewModel?.extractRatedfilenames()
            .map { URL(string: $0)?.path ?? $0 } ?? []

        let process = RsyncProcessStreaming.RsyncProcess(
            arguments: arguments,
            hiddenID: 0,
            handlers: streamingHandlers,
            useFileHandler: true
        )
        do {
            try process.executeProcess()
            activeStreamingProcess = process
        } catch {
            Logger.process.debugMessageOnly("Rsync executeProcess failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    init(
        configuration: SynchronizeConfiguration,
        dryrun: Bool = true,
        sidebarPhotoCullingViewModel: SidebarPhotoCullingViewModel
    ) {
        self.config = configuration
        self.dryrun = dryrun
        self.sidebarPhotoCullingViewModel = sidebarPhotoCullingViewModel
    }

    deinit {
        Logger.process.debugMessageOnly("ExecuteCopyFiles: DEINIT")
    }

    private func setupStreamingHandlers() {
        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { [weak self] count in
                Task { @MainActor in
                    let progress = Double(count)
                    self?.progress = progress
                    self?.onProgressUpdate?(progress)
                }
            },
            processTermination: { [weak self] output, hiddenID in
                Task { @MainActor in
                    await self?.handleProcessTermination(
                        stringoutputfromrsync: output,
                        hiddenID: hiddenID
                    )
                }
            },
            cleanup: cleanup
        )
    }

    private func handleProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) async {
        let linesCount = stringoutputfromrsync?.count ?? 0

        // Create view output asynchronously - this returns [RsyncOutputData]
        let viewOutput = await ActorCreateOutputforView().createOutputForView(stringoutputfromrsync)

        // Create the result
        let result = CopyDataResult(
            output: stringoutputfromrsync,
            viewOutput: viewOutput,
            linesCount: linesCount
        )

        // Call completion handler
        onCompletion?(result)

        // Clean up
        cleanup()
    }

    private func cleanup() {
        activeStreamingProcess = nil
        streamingHandlers = nil
    }
}
