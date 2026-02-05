//
//  CacheStatisticsView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 05/02/2026.
//

import Combine
import SwiftUI

struct CacheStatisticsView: View {
    @State private var statistics: (hits: Int, misses: Int, evictions: Int, hitRate: Double)?
    @State private var refreshTimer: AnyCancellable?
    let thumbnailProvider: ThumbnailProvider

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Cache Statistics")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()
                Button(action: refreshStatistics) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let stats = statistics {
                HStack(spacing: 10) {
                    // Hit Rate - Compact circular indicator
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: min(stats.hitRate / 100, 1.0))
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text(String(format: "%.0f", stats.hitRate))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                            Text("%")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 36, height: 36)

                    Divider()
                        .frame(height: 30)

                    // Hits and Misses - Compact horizontal
                    StatisticItemView(
                        imagelabel: "memorychip",
                        value: stats.hits,
                        color: .green
                    )
                    StatisticItemView(
                        imagelabel: "internaldrive",
                        value: stats.misses,
                        color: .orange
                    )
                    StatisticItemView(
                        imagelabel: "trash",
                        value: stats.evictions,
                        color: .red
                    )

                    Spacer()
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(8)
            }
        }
        .padding(10)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .onAppear(perform: setup)
        .onDisappear(perform: cleanup)
    }

    private func refreshStatistics() {
        Task {
            let stats = await thumbnailProvider.getCacheStatistics()
            await MainActor.run {
                self.statistics = stats
            }
        }
    }

    private func setup() {
        refreshStatistics()
        // Refresh every 5 seconds
        refreshTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                refreshStatistics()
            }
    }

    private func cleanup() {
        refreshTimer?.cancel()
    }
}

// MARK: - Statistic Item

struct StatisticItemView: View {
    let imagelabel: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: imagelabel)
                .font(.system(size: 12, weight: .semibold))

            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}
