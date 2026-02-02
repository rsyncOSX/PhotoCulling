import SwiftUI

struct FileContentView: View {
    @Bindable var viewModel: SidebarPhotoCullingViewModel

    let selectedSource: FolderSource?
    let files: [FileItem]
    let scanning: Bool
    let creatingThumbnails: Bool
    let issorting: Bool
    let progress: Double
    let max: Double

    @Binding var isShowingPicker: Bool

    let filetableview: AnyView

    var body: some View {
        Group {
            if selectedSource == nil {
                // Empty State when no catalog is selected
                ContentUnavailableView {
                    Label("No Catalog Selected", systemImage: "folder.badge.plus")
                } description: {
                    Text("Select a folder from the sidebar or add a new one to start scanning.")
                } actions: {
                    Button("Add Catalog") { isShowingPicker = true }
                }
            } else if files.isEmpty && !scanning {
                ContentUnavailableView {
                    Label("No Files Found", systemImage: "folder.badge.plus")
                } description: {
                    Text("This catalog does not contain ARW images, or the images are empty. Please try scanning another catalog.")
                }
            } else if files.isEmpty && scanning {
                ProgressView("Scanning directory...")
            } else if creatingThumbnails {
                ProgressCount(max: Double(max),
                              progress: min(Swift.max(progress, 0), Double(max)),
                              statusText: "Creating Thumbnails or extracting JPGs")
            } else {
                ZStack {
                    VStack(alignment: .leading) {
                        HStack {
                            ConditionalGlassButton(
                                systemImage: "document.on.document",
                                text: "Copy tagged",
                                helpText: "Copy tagged images to destination..."
                            ) {
                                viewModel.sheetType = .copytasksview
                                viewModel.showcopytask = true
                            }
                            .disabled(viewModel.selectedSource == nil)

                            ConditionalGlassButton(
                                systemImage: "trash.fill",
                                text: "Clear tagged",
                                helpText: "Clear tagged files"
                            ) {
                                viewModel.alertType = .clearToggledFiles
                                viewModel.showingAlert = true
                            }
                            .disabled(viewModel.creatingthumbnails)

                            if !viewModel.files.isEmpty {
                                Picker("Rating", selection: $viewModel.rating) {
                                    // Iterate over the range 0 to 5
                                    ForEach(0 ... 5, id: \.self) { number in
                                        Text("\(number)").tag(number)
                                    }
                                }
                                .pickerStyle(DefaultPickerStyle())
                                .frame(width: 100)
                            }
                        }
                        .padding()

                        filetableview
                    }

                    if issorting {
                        HStack {
                            ProgressView()

                            Text("Sorting files, please wait...")
                                .font(.title)
                                .foregroundColor(Color.green)
                        }
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}
