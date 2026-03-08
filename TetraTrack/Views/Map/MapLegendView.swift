//
//  MapLegendView.swift
//  TetraTrack
//
//  Unified map legend component for all discipline map views.
//

import SwiftUI

// MARK: - Map Legend Item

struct MapLegendItem: Identifiable {
    let id = UUID()
    let label: String
    let color: Color
}

// MARK: - Map Legend Layout

enum MapLegendLayout {
    case horizontal
    case vertical
}

// MARK: - Map Legend View

struct MapLegendView: View {
    let items: [MapLegendItem]
    var layout: MapLegendLayout = .horizontal

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        legendEntry(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.cardBackground)
                .clipShape(Capsule())

            case .vertical:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(item.color)
                                .frame(width: 20, height: 4)
                            Text(item.label)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            }
        }
    }

    private func legendEntry(_ item: MapLegendItem) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(item.color)
                .frame(width: 8, height: 8)
            Text(item.label)
                .font(.caption2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label) color indicator")
    }
}

// MARK: - Factory Methods

extension MapLegendView {

    /// Vertical legend showing only gaits present in the route
    static func gaitLegend(usedGaits: [GaitType]) -> MapLegendView {
        MapLegendView(
            items: usedGaits.map { MapLegendItem(label: $0.rawValue, color: AppColors.gait($0)) },
            layout: .vertical
        )
    }

    /// Horizontal legend showing all 4 gaits
    static func allGaitsLegend() -> MapLegendView {
        MapLegendView(
            items: [GaitType.walk, .trot, .canter, .gallop]
                .map { MapLegendItem(label: $0.rawValue, color: AppColors.gait($0)) },
            layout: .horizontal
        )
    }

    /// Horizontal legend showing all 4 running phases
    static func runningPhaseLegend() -> MapLegendView {
        MapLegendView(
            items: RunningPhase.allCases.map {
                MapLegendItem(label: $0.rawValue, color: AppColors.gait($0.toGaitType))
            },
            layout: .horizontal
        )
    }
}
