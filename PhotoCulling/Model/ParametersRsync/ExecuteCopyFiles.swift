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

    private let fileName = "copyfilelist.txt"
    private var savePath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    let config: SynchronizeConfiguration
    var dryrun: Bool
    var rating: Int
    var copytaggedfiles: Bool
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

        guard var arguments, let streamingHandlers, arguments.count > 2 else { return }
        // Must add the --include-from=my_list.txt ahead of source and destination
        let includeparameter = "--include-from=" + savePath.path
        arguments.insert("--exclude='*'", at: arguments.count - 2)
        arguments.insert(includeparameter, at: arguments.count - 2)

        /*
         // rsync -av --include-from=my_list.txt /path/to/source/ /path/to/destination/
         */

        Logger.process.debugMessageOnly("ExecuteCopyFiles: writing copyfilelist at \(savePath.path)")

        if copytaggedfiles {
            let filelist = sidebarPhotoCullingViewModel?.extractTaggedfilenames()
                .map { URL(string: $0)?.path ?? $0 } ?? []
            do {
                try writeincludefilelist(filelist, to: savePath)
            } catch {}
        } else {
            let filelist = sidebarPhotoCullingViewModel?.extractRatedfilenames(rating)
                .map { URL(string: $0)?.path ?? $0 } ?? []
            do {
                try writeincludefilelist(filelist, to: savePath)
            } catch {}
        }

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
            Logger.process.debugMessageOnly("ExecuteCopyFiles: rsync executeProcess failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    init(
        configuration: SynchronizeConfiguration,
        dryrun: Bool = true,
        rating: Int = 0,
        copytaggedfiles: Bool = true,
        sidebarPhotoCullingViewModel: SidebarPhotoCullingViewModel
    ) {
        self.config = configuration
        self.dryrun = dryrun
        self.rating = rating
        self.sidebarPhotoCullingViewModel = sidebarPhotoCullingViewModel
        self.copytaggedfiles = copytaggedfiles
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

    private func writeincludefilelist(_ filelist: [String], to URLpath: URL) throws {
        let newlogadata = filelist.joined(separator: "\n") + "\n"
        guard let newdata = newlogadata.data(using: .utf8) else {
            throw NSError(domain: "ExecuteCopyFiles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode log data"])
        }
        do {
            try newdata.write(to: URLpath)
        } catch {
            throw NSError(domain: "ExecuteCopyFiles", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to write filelist to URL: \(error)"])
        }
    }
}
