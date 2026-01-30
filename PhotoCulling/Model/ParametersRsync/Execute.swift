//
//  Execute.swift
//  RsyncUI
//
//  Created by Thomas Evensen on 10/06/2025.
//

import Foundation
import OSLog
import RsyncProcessStreaming

enum ErrorDatatoSynchronize: LocalizedError {
    case thereisdatatosynchronize(idwitherror: String)

    var errorDescription: String? {
        switch self {
        case let .thereisdatatosynchronize(idwitherror):
            "There are errors in tagging data\n for synchronize ID \(idwitherror)\n"
                + "Most likely number of rows\n> 20 lines and no data to synchronize"
        }
    }
}

@MainActor
final class Execute {
    /// Report progress to caller
    var localfileHandler: (Int) -> Void
    // Streaming strong references
    private var streamingHandlers: RsyncProcessStreaming.ProcessHandlers?
    private var activeStreamingProcess: RsyncProcessStreaming.RsyncProcess?

    func startcopyfiles(config: SynchronizeConfiguration) {
        streamingHandlers = CreateStreamingHandlers().createHandlers(
            fileHandler: localfileHandler,
            processTermination: { output, hiddenID in
                self.processTermination(stringoutputfromrsync: output, hiddenID)
            }
        )

        if let arguments = ArgumentsSynchronize(config: config).argumentsSynchronize(dryRun: false,
                                                                                     forDisplay: false) {
            guard let streamingHandlers else { return }
            let process = RsyncProcessStreaming.RsyncProcess(
                arguments: arguments,
                hiddenID: config.hiddenID,
                handlers: streamingHandlers,
                useFileHandler: true
            )

            do {
                try process.executeProcess()
                activeStreamingProcess = process
            } catch let err {
                let error = err
                // Logger.process.debugMessageOnly(error)
            }
        }
    }

    init(fileHandler: @escaping (Int) -> Void) {
        localfileHandler = fileHandler
    }

    deinit {
        Logger.process.debugMessageOnly("Execute: DEINIT")
    }

    private func processTermination(stringoutputfromrsync _: [String]?, _: Int?) {}
}
