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
    @FocusedBinding(\.navigateUp) private var navigateUp
    @FocusedBinding(\.navigateDown) private var navigateDown

    var body: some Commands {
        CommandMenu("Table Navigation") {
            CommandButton("Tag row", action: { togglerow = true }, shortcut: "t")
            CommandButton("Abort task", action: { aborttask = true }, shortcut: "k")
            
            Divider()
            
            CommandButton("Previous row", action: { navigateUp = true }, shortcut: .init(.upArrow, modifiers: [.command]))
            CommandButton("Next row", action: { navigateDown = true }, shortcut: .init(.downArrow, modifiers: [.command]))
        }
    }
}

// MARK: - Reusable Command Button

struct CommandButton: View {
    let label: String
    let action: () -> Void
    let shortcut: KeyboardShortcut?
    
    init(_ label: String, action: @escaping () -> Void, shortcut: String? = nil) {
        self.label = label
        self.action = action
        if let shortcut = shortcut {
            self.shortcut = .init(KeyEquivalent(shortcut.first ?? "t"), modifiers: [.command])
        } else {
            self.shortcut = nil
        }
    }
    
    init(_ label: String, action: @escaping () -> Void, shortcut: KeyboardShortcut) {
        self.label = label
        self.action = action
        self.shortcut = shortcut
    }
    
    var body: some View {
        if let shortcut = shortcut {
            Button(label, action: action).keyboardShortcut(shortcut)
        } else {
            Button(label, action: action)
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

// MARK: - Focused Value Keys

struct FocusedTogglerow: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct FocusedAborttask: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct FocusedNavigateUp: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct FocusedNavigateDown: FocusedValueKey {
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
    
    var navigateUp: FocusedNavigateUp.Value? {
        get { self[FocusedNavigateUp.self] }
        set { self[FocusedNavigateUp.self] = newValue }
    }
    
    var navigateDown: FocusedNavigateDown.Value? {
        get { self[FocusedNavigateDown.self] }
        set { self[FocusedNavigateDown.self] = newValue }
    }
}
