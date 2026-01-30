//
//  ExecuteCopyFiles.swift
//  Created by Thomas Evensen on 10/06/2025.
//

import Foundation
import OSLog
import RsyncProcessStreaming

@MainActor
final class ExecuteCopyFiles {
    /// Report progress to caller
    var localfileHandler: (Int) -> Void
    var localprocessTermination: ([String]?, Int?) -> Void
    // Streaming strong references
    private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?

    func startcopyfiles(config: SynchronizeConfiguration) {
        streamingHandlers = CreateStreamingHandlers().createHandlers(
            fileHandler: localfileHandler,
            processTermination: localprocessTermination
        )

        if let arguments = ArgumentsSynchronize(config: config).argumentsSynchronize(dryRun: false,
                                                                                     forDisplay: false) {
            guard let streamingHandlers else { return }

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
    }

    init(fileHandler: @escaping (Int) -> Void,
         processTermination: @escaping ([String]?, Int?) -> Void) {
        localfileHandler = fileHandler
        localprocessTermination = processTermination
    }

    deinit {
        Logger.process.debugMessageOnly("ExecuteCopyFiles: DEINIT")
    }
}

