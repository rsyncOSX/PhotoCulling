//
//  TooggleCommand.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 28/01/2026.
//

import Foundation
import SwiftUI

struct ToggleCommands: Commands {
    @FocusedBinding(\.togglerow) private var togglerow
    @FocusedBinding(\.aborttask) private var aborttask

    var body: some Commands {
        CommandMenu("Toggle row") {
            Togglerow(tagsnapshot: $togglerow)

            Divider()

            Abborttask(aborttask: $aborttask)
        }
    }
}

struct Togglerow: View {
    @Binding var tagsnapshot: Bool?

    var body: some View {
        Button {
            tagsnapshot = true
        } label: {
            Text("Tag row")
        }
        .keyboardShortcut("t", modifiers: [.command])
    }
}

struct Abborttask: View {
    @Binding var aborttask: Bool?

    var body: some View {
        Button {
            aborttask = true
        } label: {
            Text("Abort task")
        }
        .keyboardShortcut("k", modifiers: [.command])
    }
}

struct FocusedTogglerow: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct FocusedAborttask: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var togglerow: FocusedTogglerow.Value? {
        get { self[FocusedTogglerow.self] }
        set { self[FocusedTogglerow.self] = newValue }
    }

    var aborttask: FocusedAborttask.Value? {
        get { self[FocusedAborttask.self] }
        set { self[FocusedAborttask.self] = newValue }
    }
}
