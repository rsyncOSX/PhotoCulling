//
//  ArgumentsSynchronize.swift
//  RsyncUI
//

import Foundation
import RsyncArguments

@MainActor
final class ArgumentsSynchronize {
    var config: SynchronizeConfiguration?

    func argumentsSynchronize(
        dryRun: Bool,
        forDisplay: Bool
    ) -> [String]? {
        if let config {
            let params = Params().params(config: config)
            let rsyncparameterssynchronize = RsyncParametersSynchronize(parameters: params)

            do {
                try rsyncparameterssynchronize.argumentsForSynchronize(forDisplay: forDisplay,
                                                                       verify: false,
                                                                       dryrun: dryRun)
                return rsyncparameterssynchronize.computedArguments
            } catch {
                return nil
            }
        }
        return nil
    }

    init(config: SynchronizeConfiguration?) {
        self.config = config
    }
}
