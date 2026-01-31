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
        HStack {
            VStack(alignment: .leading) {
                DetailsViewHeading(remotedatanumbers: remotedatanumbers)

                Spacer()

                if remotedatanumbers.datatosynchronize {
                    VStack(alignment: .leading) {
                        let filesChangedText = remotedatanumbers.filestransferredInt == 1
                            ? "1 file changed"
                            : "\(remotedatanumbers.filestransferredInt) files changed"
                        Text(filesChangedText)
                        let transferSizeText = remotedatanumbers.totaltransferredfilessizeInt == 1
                            ? "byte for transfer"
                            : "\(remotedatanumbers.totaltransferredfilessize) bytes for transfer"
                        Text(transferSizeText)
                    }
                    .padding()
                    .foregroundStyle(.white)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.blue.gradient)
                    }
                    .padding()
                } else {
                    Text("No data to synchronize")
                        .font(.title2)
                        .padding()
                        .foregroundStyle(.white)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.gradient)
                        }
                        .padding()
                }
            }

            if let records = remotedatanumbers.outputfromrsync {
                Table(records) {
                    TableColumn("Output from rsync (\(records.count) rows)") { data in
                        RsyncOutputRowView(record: data.record)
                    }
                }
            } else {
                Text("No rsync output available")
                    .foregroundColor(.secondary)
            }
            
            VStack {
                Spacer()
                
                Button("Close", role: .close) {
                    dismiss()
                }
                .buttonStyle(RefinedGlassButtonStyle())
            }
            .padding()
            
        }
        .frame(
            minWidth: 1000,
            idealWidth: 1000,
            minHeight: 800,
            idealHeight: 800,
            alignment: .init(horizontal: .center, vertical: .center)
        )
    }
}

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
