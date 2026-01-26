import SwiftUI

struct ZoomableImageView: View {
    let nsImage: NSImage?

    @State private var currentScale: CGFloat = 3.0 // Start at 3x as requested previously
    @State private var lastScale: CGFloat = 3.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @Environment(\.dismiss) var dismiss

    // Define the zoom level you want to toggle to
    private let zoomLevel: CGFloat = 3.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let nsImage {
                GeometryReader { geo in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                // 1. Zoom
                                MagnificationGesture()
                                    .onChanged { value in
                                        currentScale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = currentScale
                                        if currentScale < 1.0 {
                                            resetToFit()
                                        }
                                    },

                                // 2. Pan
                                DragGesture()
                                    .onChanged { value in
                                        if currentScale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        // Toggle Logic
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if currentScale > 1.0 {
                                    // Currently Zoomed -> Reset to Fit
                                    resetToFit()
                                } else {
                                    // Currently Fit -> Zoom to 3x
                                    zoomToTarget()
                                }
                            }
                        }
                }
            } else {
                Text("No Image Available")
                    .foregroundStyle(.white)
            }

            // UI Overlay
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()

                if currentScale <= 1.0 {
                    Text("Double Tap to Zoom")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 20)
                } else {
                    Text("Double Tap to Fit Screen")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 20)
                }
            }
        }
    }

    // Helper: Reset to Fit View
    private func resetToFit() {
        currentScale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    // Helper: Zoom to Target (3x)
    private func zoomToTarget() {
        currentScale = zoomLevel
        lastScale = zoomLevel
        offset = .zero
        lastOffset = .zero
    }
}
