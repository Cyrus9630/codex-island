import Foundation
import SwiftUI

enum ProjectMarker: String, CaseIterable, Identifiable {
    case standard = "default"
    case inverted
    case red
    case orange
    case yellow
    case green
    case blue
    case purple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "默认颜色"
        case .inverted: "反转色"
        case .red: "红色"
        case .orange: "橙色"
        case .yellow: "黄色"
        case .green: "绿色"
        case .blue: "蓝色"
        case .purple: "紫色"
        }
    }

    var menuColor: Color {
        switch self {
        case .standard: .secondary
        case .inverted: .white
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }

    var menuSystemImage: String {
        switch self {
        case .standard: "circle"
        case .inverted: "circle.lefthalf.filled"
        case .red: "heart.fill"
        case .orange: "flame.fill"
        case .yellow: "sun.max.fill"
        case .green: "leaf.fill"
        case .blue: "drop.fill"
        case .purple: "sparkles"
        }
    }
}

@MainActor
final class ProjectMarkerStore {
    private let defaults: UserDefaults
    private let storageKey = "CodexNotchNavigator.projectMarkers.v1"
    private(set) var markers: [String: ProjectMarker] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    func marker(for projectID: String) -> ProjectMarker {
        markers[projectID] ?? .standard
    }

    func set(_ marker: ProjectMarker, for projectID: String) {
        if marker == .standard {
            markers.removeValue(forKey: projectID)
        } else {
            markers[projectID] = marker
        }
        persist()
    }

    private func reload() {
        guard let stored = defaults.dictionary(forKey: storageKey) as? [String: String] else {
            markers = [:]
            return
        }
        markers = stored.reduce(into: [:]) { result, entry in
            if let marker = ProjectMarker(rawValue: entry.value), marker != .standard {
                result[entry.key] = marker
            }
        }
    }

    private func persist() {
        defaults.set(markers.mapValues(\.rawValue), forKey: storageKey)
    }
}
