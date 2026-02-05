//
//  CacheStatisticsView.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 05/02/2026.
//

import SwiftUI
import Combine

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
                            Text("Hit Rate")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", stats.hitRate))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
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
                        }
                        .frame(width: 50, height: 50)

                        Spacer()
                    }

                    Divider()
                        .padding(.vertical, 4)

                    // Hits and Misses
                    HStack(spacing: 12) {
                        StatisticItemView(
                            label: "Hits",
                            value: stats.hits,
                            color: .green
                        )
                        StatisticItemView(
                            label: "Misses",
                            value: stats.misses,
                            color: .orange
                        )
                        StatisticItemView(
                            label: "Evictions",
                            value: stats.evictions,
                            color: .red
                        )
                    }

                    // Total requests
                    let total = stats.hits + stats.misses
                    HStack(spacing: 12) {
                        Text("Total Requests")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(total)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
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
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

