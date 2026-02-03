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

    // Security-scoped URL references
    private var sourceAccessedURL: URL?
    private var destAccessedURL: URL?

    /// State
    var progress: Double = 0

    // Callbacks
    var onProgressUpdate: ((Double) -> Void)?
    var onCompletion: ((CopyDataResult) -> Void)?

    func startcopyfiles() {
        let arguments = ArgumentsSynchronize(config: config).argumentsSynchronize(
            dryRun: dryrun
        )

        setupStreamingHandlers()

        guard var arguments, let streamingHandlers, arguments.count > 2 else { return }

        let count = arguments.count
        let source = arguments[count - 2]
        let dest = arguments[count - 1]

        // Remove source and dest from arguments
        arguments.removeLast()
        arguments.removeLast()

        // DON'T add duplicate flags - they're already in arguments!
        // Just add the ones that aren't there
        arguments.append("--no-extended-attributes")

        // Add filter file if needed
        let includeparameter = "--include-from=" + savePath.path
        arguments.append(includeparameter)

        if dryrun == false {
            arguments.append("--include=*/")
        }
        arguments.append("--exclude=*")

        guard let sourceURL = getAccessedURL(fromBookmarkKey: "sourceBookmark", fallbackPath: source),
              let destURL = getAccessedURL(fromBookmarkKey: "destBookmark", fallbackPath: dest)
        else {
            print("Failed to access folders")
            return
        }

        self.sourceAccessedURL = sourceURL
        self.destAccessedURL = destURL

        arguments.append(sourceURL.path + "/")
        arguments.append(destURL.path + "/")

        print("DEBUG: Final arguments: \(arguments)")
        print("DEBUG: Number of arguments: \(arguments.count)")

        // Write filter file
        Logger.process.debugMessageOnly("ExecuteCopyFiles: writing copyfilelist at \(savePath.path)")

        if copytaggedfiles {
            if let filelist = sidebarPhotoCullingViewModel?.extractTaggedfilenames() {
                do {
                    try writeincludefilelist(filelist, to: savePath)
                } catch {
                    print("ERROR: Failed to write filter file: \(error)")
                }
            }
        } else {
            if let filelist = sidebarPhotoCullingViewModel?.extractRatedfilenames(rating) {
                do {
                    try writeincludefilelist(filelist, to: savePath)
                } catch {
                    print("ERROR: Failed to write filter file: \(error)")
                }
            }
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
            print("ERROR: executeProcess failed: \(error)")
            Task { @MainActor in
                self.cleanup()
            }
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
        // Note: Can't call async cleanup in deinit, but the URLs will be released
        // when the properties are deallocated
    }

    private func setupStreamingHandlers() {
        streamingHandlers = CreateStreamingHandlers().createHandlersWithCleanup(
            fileHandler: { [weak self] count in
                print("DEBUG fileHandler: count=\(count)")
                Task { @MainActor in
                    let progress = Double(count)
                    self?.progress = progress
                    self?.onProgressUpdate?(progress)
                }
            },
            processTermination: { [weak self] output, hiddenID in
                print("DEBUG processTermination: output lines=\(output?.count ?? 0), hiddenID=\(hiddenID ?? -1)")
                Task { @MainActor in
                    await self?.handleProcessTermination(
                        stringoutputfromrsync: output,
                        hiddenID: hiddenID
                    )
                }
            },
            cleanup: { [weak self] in
                print("DEBUG cleanup called")
                Task { @MainActor in
                    self?.cleanup()
                }
            }
        )
    }

    private func handleProcessTermination(stringoutputfromrsync: [String]?, hiddenID _: Int?) async {
        let linesCount = stringoutputfromrsync?.count ?? 0

        // Create view output asynchronously
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
        // Stop accessing security-scoped resources
        sourceAccessedURL?.stopAccessingSecurityScopedResource()
        destAccessedURL?.stopAccessingSecurityScopedResource()

        sourceAccessedURL = nil
        destAccessedURL = nil

        activeStreamingProcess = nil
        streamingHandlers = nil
    }

    private func writeincludefilelist(_ filelist: [String], to URLpath: URL) throws {
        let newlogadata = filelist.joined(separator: "\n") + "\n"
        guard let newdata = newlogadata.data(using: .utf8) else {
            throw NSError(domain: "ExecuteCopyFiles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode log data"])
        }
        do {
            try newdata.write(to: URLpath, options: .atomic)
        } catch {
            throw NSError(
                domain: "ExecuteCopyFiles",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to write filelist to URL: \(error)"]
            )
        }
    }

    func getAccessedURL(fromBookmarkKey key: String, fallbackPath: String) -> URL? {
        // Try bookmark first
        if let bookmarkData = UserDefaults.standard.data(forKey: key) {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    print("ERROR: Failed to start accessing bookmark for \(key)")
                    // Try fallback instead
                    return tryFallbackPath(fallbackPath, key: key)
                }
                print("DEBUG: Successfully resolved bookmark for \(key)")
                return url
            } catch {
                print("ERROR: Bookmark resolution failed for \(key): \(error)")
                // Try fallback instead
                return tryFallbackPath(fallbackPath, key: key)
            }
        }
        
        // If no bookmark exists, try the fallback path
        return tryFallbackPath(fallbackPath, key: key)
    }

    private func tryFallbackPath(_ fallbackPath: String, key: String) -> URL? {
        print("WARNING: No bookmark found for \(key), attempting direct path access")
        let fallbackURL = URL(fileURLWithPath: fallbackPath)
        guard fallbackURL.startAccessingSecurityScopedResource() else {
            print("ERROR: Failed to access fallback path for \(key)")
            return nil
        }
        print("DEBUG: Successfully accessed fallback path for \(key)")
        return fallbackURL
    }
}
