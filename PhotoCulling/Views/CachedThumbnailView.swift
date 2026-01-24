import SwiftUI

struct CachedThumbnailView: View {
    let url: URL

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var isPresentingFullScreen = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600, maxHeight: 600)
                    .shadow(radius: 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                
                // "View Full Size" button overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresentingFullScreen = true
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.5))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                        .padding(.bottom, 12)
                    }
                }

            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                ContentUnavailableView("Select an Image", systemImage: "photo")
            }
        }
        .task(id: url) {
            isLoading = true
            // Fetch a larger resolution for better zooming quality
            image = await ThumbnailProvider.shared.thumbnail(for: url, targetSize: 2560)
            isLoading = false
        }
        // FIX: Use .sheet instead of .fullScreenCover for macOS
        .sheet(isPresented: $isPresentingFullScreen) {
            ZoomableImageView(nsImage: image)
                // Set a large default size for the sheet window
                .frame(minWidth: 1000, minHeight: 800)
                // Hide the standard window title bar for a cleaner "viewer" look
                //.windowStyle(.hiddenTitleBar)
        }
    }
}

// MARK: - Zoomable & Panable View
struct ZoomableImageView: View {
    let nsImage: NSImage?
    
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    @Environment(\.dismiss) var dismiss

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
                        // Combine Pinch (Zoom) and Drag (Pan)
                        .gesture(
                            SimultaneousGesture(
                                // 1. Zoom (Pinch on Trackpad)
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        currentScale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if currentScale < 1.0 {
                                            withAnimation {
                                                currentScale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    },
                                
                                // 2. Pan (Click & Drag OR Two-Finger Swipe on Trackpad)
                                DragGesture()
                                    .onChanged { value in
                                        // Only allow panning if zoomed in
                                        if currentScale > 1.0 {
                                            let newOffset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            offset = newOffset
                                        }
                                    }
                                    .onEnded { _ in
                                        if currentScale > 1.0 {
                                            lastOffset = offset
                                        } else {
                                            lastOffset = .zero
                                            offset = .zero
                                        }
                                    }
                            )
                        )
                }
            } else {
                Text("No Image Available")
                    .foregroundStyle(.white)
            }
            
            // Close Button (Top Right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.7))
                            //.hoverEffect(.highlight)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
                
                // Instructions overlay
                if currentScale <= 1.0 {
                    Text("Pinch to Zoom • Drag to Pan")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 20)
                        .transition(.opacity)
                }
            }
        }
        // Double click or double tap to reset
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                currentScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}

