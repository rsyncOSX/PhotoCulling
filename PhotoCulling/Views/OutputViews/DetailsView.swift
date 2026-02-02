//
//  DetailsView.swift
//  RsyncVerify
//
//  Created by Thomas Evensen on 07/06/2024.
//

import SwiftUI

struct DetailsView: View {
    @Environment(\.dismiss) var dismiss

    let remotedatanumbers: RemoteDataNumbers

    var body: some View {
        HStack(spacing: 16) {
            leftPanelContent
                .frame(minWidth: 300)

            dividerView

            rsyncOutputContent
                .frame(minWidth: 250)

            closeButtonPanel
                .frame(width: 120)
        }
        .frame(
            minWidth: 900,
            idealWidth: 900,
            minHeight: 500,
            idealHeight: 500,
            alignment: .init(horizontal: .center, vertical: .center)
        )
        .padding()
    }

    // MARK: - Subviews

    private var leftPanelContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailsViewHeading(remotedatanumbers: remotedatanumbers)

            Spacer()

            syncStatusBox
        }
    }

    private var syncStatusBox: some View {
        Group {
            if remotedatanumbers.datatosynchronize {
                syncDataContent
            } else {
                noSyncDataContent
            }
        }
        .padding()
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.gradient)
        }
        .padding()
    }

    private var syncDataContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            let filesChangedText = remotedatanumbers.filestransferredInt == 1
                ? "1 file changed"
                : "\(remotedatanumbers.filestransferredInt) files changed"
            Text(filesChangedText)

            let transferSizeText = remotedatanumbers.totaltransferredfilessizeInt == 1
                ? "byte for transfer"
                : "\(remotedatanumbers.totaltransferredfilessize) bytes for transfer"
            Text(transferSizeText)
        }
    }

    private var noSyncDataContent: some View {
        Text("No data to synchronize")
            .font(.title2)
    }

    private var rsyncOutputContent: some View {
        Group {
            if let records = remotedatanumbers.outputfromrsync {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        RsyncOutputRowView(record: data.record)
                    }
                }
            } else {
                VStack {
                    Spacer()
                    Text("No rsync output available")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var dividerView: some View {
        Divider()
    }

    private var closeButtonPanel: some View {
        VStack {
            Spacer()

            Button("Close", role: .close) {
                dismiss()
            }
            .buttonStyle(RefinedGlassButtonStyle())

            Spacer()
        }
        .padding()
    }
}

// MARK: - RsyncOutputRowView

public struct RsyncOutputRowView: View {
    let record: String

    public init(record: String) {
        self.record = record
    }

    public var body: some View {
        Text(record)
            .font(.caption)
            .textSelection(.enabled)
    }
}
