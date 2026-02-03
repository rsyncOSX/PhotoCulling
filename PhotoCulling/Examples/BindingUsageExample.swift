//
//  BindingUsageExample.swift
//  PhotoCulling
//
//  This file demonstrates how to properly work with @Binding in SwiftUI
//  specifically for the FolderSource type used in PhotoCulling.
//

import SwiftUI

// MARK: - Example 1: Reading Binding Values

extension CopyTasksView {
    
    /// Example of reading the selectedSource binding value
    /// This shows various ways to access the optional binding safely
    private func demonstrateReadingBindingValue() {
        // Method 1: Optional chaining (simplest for one-off access)
        if let sourcePath = selectedSource?.url.path {
            print("Source path: \(sourcePath)")
        }
        
        // Method 2: Guard let (best for functions that need the value)
        guard let source = selectedSource else {
            print("No source selected")
            return
        }
        print("Source name: \(source.name)")
        print("Source URL: \(source.url)")
        
        // Method 3: If let (when you want to handle both cases)
        if let source = selectedSource {
            print("Selected source: \(source.name)")
        } else {
            print("No source selected")
        }
        
        // Method 4: Nil coalescing for default values
        let displayName = selectedSource?.name ?? "No Selection"
        print("Display: \(displayName)")
    }
}

// MARK: - Example 2: Writing/Modifying Binding Values

extension CopyTasksView {
    
    /// Example of modifying the selectedSource binding value
    /// Changes will automatically propagate to the parent view
    private func demonstrateModifyingBindingValue() {
        // Setting to a new value
        let newSource = FolderSource(
            name: "Documents",
            url: URL(fileURLWithPath: "/Users/username/Documents")
        )
        selectedSource = newSource
        
        // Clearing the selection
        selectedSource = nil
        
        // Conditional modification
        if let currentSource = selectedSource {
            // Can't directly modify properties since FolderSource uses 'let'
            // Instead, create a new instance with updated values
            let updatedSource = FolderSource(
                name: "Updated Name",
                url: currentSource.url
            )
            selectedSource = updatedSource
        }
    }
}

// MARK: - Example 3: Using Binding in View Body

extension CopyTasksView {
    
    /// Example computed property showing binding usage in SwiftUI views
    var exampleBindingInView: some View {
        VStack {
            // Display current selection
            if let source = selectedSource {
                VStack(alignment: .leading) {
                    Text("Current Selection:")
                        .font(.headline)
                    Text("Name: \(source.name)")
                    Text("Path: \(source.url.path)")
                }
                .padding()
            } else {
                Text("No folder selected")
                    .foregroundColor(.secondary)
                    .padding()
            }
            
            // Button that modifies the binding
            Button("Clear Selection") {
                selectedSource = nil
            }
            .disabled(selectedSource == nil)
        }
    }
}

// MARK: - Example 4: Observing Binding Changes

extension CopyTasksView {
    
    /// Example of how to react to changes in the binding value
    var exampleObservingChanges: some View {
        VStack {
            Text("Watching for changes...")
        }
        // React to changes using .task
        .task(id: selectedSource) {
            guard let source = selectedSource else {
                print("Selection cleared")
                return
            }
            print("New selection: \(source.name)")
            // Perform actions based on new selection
            sourcecatalog = source.url.path
        }
        // Alternative: Use .onChange
        .onChange(of: selectedSource) { oldValue, newValue in
            if let old = oldValue {
                print("Previous: \(old.name)")
            }
            if let new = newValue {
                print("New: \(new.name)")
            }
        }
    }
}

// MARK: - Example 5: Passing Binding to Child Views

extension CopyTasksView {
    
    /// Example of passing the binding to a child view
    var examplePassingBindingToChild: some View {
        VStack {
            // Pass the entire binding using $
            ExampleChildView(selectedFolder: $selectedSource)
            
            // Child views can read and modify the binding
            // Changes in the child automatically update the parent
        }
    }
}

// Example child view that accepts a binding
struct ExampleChildView: View {
    @Binding var selectedFolder: FolderSource?
    
    var body: some View {
        VStack {
            if let folder = selectedFolder {
                Text("Child view sees: \(folder.name)")
            }
            
            Button("Modify in Child") {
                // Modifications here affect the parent's binding
                if let current = selectedFolder {
                    selectedFolder = FolderSource(
                        name: "Modified by Child",
                        url: current.url
                    )
                }
            }
        }
    }
}

// MARK: - Example 6: Actual Usage Pattern from CopyTasksView

extension CopyTasksView {
    
    /// This is the actual pattern used in CopyTasksView.swift
    /// It demonstrates the recommended approach
    var actualUsagePattern: some View {
        VStack {
            Text("Source: \(selectedSource?.name ?? "Not selected")")
        }
        // When selectedSource changes, update the local state
        .task(id: selectedSource) {
            // Safely unwrap the optional binding
            guard let selectedSource else { return }
            // Extract the path and use it
            sourcecatalog = selectedSource.url.path
        }
    }
}

// MARK: - Common Patterns Summary

/*
 SUMMARY OF BINDING PATTERNS:
 
 1. READ the value:
    - selectedSource           → Access the actual value
    - selectedSource?.property → Safe optional chaining
    - guard let/if let         → Unwrap safely
 
 2. WRITE to the value:
    - selectedSource = newValue  → Assign new value
    - selectedSource = nil       → Clear the value
 
 3. PASS to child views:
    - $selectedSource           → Pass the binding (not the value)
    - Child can read and write via the binding
 
 4. OBSERVE changes:
    - .task(id: selectedSource) { }     → React to changes
    - .onChange(of: selectedSource) { } → Handle changes
 
 5. DON'T copy:
    - You don't need to make a copy
    - The binding IS the connection
    - Direct access and assignment work perfectly
 */
