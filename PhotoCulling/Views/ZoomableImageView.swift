//
//  ZoomableImageView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 24/01/2026.
//

import SwiftUI

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
                    // FIX: Use actual image size for the frame.
                    // This ensures the image is rendered at its native resolution (or scaled down by 'fit')
                    // rather than being forced into the window geometry incorrectly.
                    let imageSize = nsImage.size

                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        // Bind the frame to the image's intrinsic size
                        .frame(width: imageSize.width, height: imageSize.height)
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                // 1. Zoom
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        currentScale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if currentScale < 1.0 {
                                            withAnimation(.spring()) {
                                                currentScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    },

                                // 2. Pan
                                DragGesture()
                                    .onChanged { value in
                                        if currentScale > 1.0 {
                                            // Calculate new offset based on the drag delta
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
                        // Center the image container in the window
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            } else {
                Text("No Image Available")
                    .foregroundStyle(.white)
            }

            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.7))
                            .background(Circle().fill(Color.black.opacity(0.1))) // Better hit target
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()

                // Instructions
                if currentScale <= 1.0 {
                    Text("Pinch to Zoom • Drag to Pan")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 20)
                        .transition(.opacity)
                }
            }
        }
        // Double click to reset
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                currentScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}
