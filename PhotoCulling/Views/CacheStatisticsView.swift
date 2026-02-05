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
        VStack(spacing: 12) {
            HStack {
                Text("Cache Statistics")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: refreshStatistics) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let stats = statistics {
                VStack(spacing: 8) {
                    // Hit Rate - Main metric
                    HStack(spacing: 12) {
                        VStack(spacing: 2) {
                            Text("% memory hits")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                        }

                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                            Circle()
                                .trim(from: 0, to: min(stats.hitRate / 100, 1.0))
                                .stroke(
                                    LinearGradient(
                                        colors: [.green, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            Text(String(format: "%.1f%%", stats.hitRate))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .padding(5)
                        }
                        .frame(width: 50, height: 50)

                        Spacer()
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Hits and Misses
                    HStack(spacing: 12) {
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
                    }
                }
                .padding(10)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading statistics...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(10)
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
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
