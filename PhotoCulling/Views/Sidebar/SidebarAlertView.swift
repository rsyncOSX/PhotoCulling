import SwiftUI

enum SidebarAlertView {
    enum AlertType {
        case extractJPGs
        case clearToggledFiles
    }

    typealias AlertActions = (
        extractJPGS: () -> Void,
        clearCaches: () -> Void
    )

    static func alert(
        type: AlertType?,
        selectedSource: FolderSource?,
        cullingManager: ObservableCullingManager,
        actions: AlertActions
    ) -> Alert {
        switch type {
        case .extractJPGs:
            return Alert(
                title: Text("Extract JPGs"),
                message: Text("Are you sure you want to extract JPG images from ARW files?"),
                primaryButton: .destructive(Text("Extract")) {
                    actions.extractJPGS()
                },
                secondaryButton: .cancel()
            )

        case .clearToggledFiles:
            return Alert(
                title: Text("Clear Tagged Files"),
                message: Text("Are you sure you want to clear all tagged files?"),
                primaryButton: .destructive(Text("Clear")) {
                    if let url = selectedSource?.url {
                        cullingManager.resetSavedFiles(in: url)
                    }
                },
                secondaryButton: .cancel()
            )

        case .none:
            return Alert(title: Text("Unknown Action"))
        }
    }
}
