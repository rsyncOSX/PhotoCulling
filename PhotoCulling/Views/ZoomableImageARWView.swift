//
//  ZoomableImageARWView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 24/01/2026.
//

import SwiftUI

struct ZoomableImageViewARW: View {
    let cgImage: CGImage?

    // State variables for zoom and pan
    @State private var currentScale: CGFloat = 3.0 // Starts zoomed in
    @State private var lastScale: CGFloat = 3.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @Environment(\.dismiss) var dismiss

    private let zoomLevel: CGFloat = 3.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let cgImage {
                GeometryReader { geo in
                    // FIX: Wrapped CGImage in UIImage for proper scaling/orientation
                    Image(decorative: cgImage, scale: 1.0, orientation: .up)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(currentScale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        currentScale = lastScale * value
                                    }
                                    .onEnded { _ in
                                        lastScale = currentScale
                                        if currentScale < 1.0 {
                                            withAnimation(.spring()) {
                                                resetToFit()
                                            }
                                        }
                                    },

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
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if currentScale > 1.0 {
                                    resetToFit()
                                } else {
                                    zoomToTarget()
                                }
                            }
                        }
                }
            } else {
                Text("No Image Available")
                    .foregroundStyle(.white)
            }

            // ... (Rest of your UI Overlay code remains the same)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.7))
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
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

    private func resetToFit() {
        currentScale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    private func zoomToTarget() {
        currentScale = zoomLevel
        lastScale = zoomLevel
        offset = .zero
        lastOffset = .zero
    }
}
