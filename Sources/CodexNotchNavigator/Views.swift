import AppKit
import CodexNotchCore
import SwiftUI

struct TopRailView: View {
    let expanded: Bool
    let unreadState: UnreadRefreshState
    let refreshing: Bool
    let onHoverCategory: (ProjectCategory) -> Void
    let onHoverLifeAndConversations: () -> Void
    let onHoverNextUnread: () -> Void
    let onOpenNextUnread: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: expanded ? 14 : 11,
                bottomTrailingRadius: expanded ? 14 : 11,
                topTrailingRadius: 0
            )
            .fill(Color.black.opacity(0.985))
            .overlay(alignment: .bottom) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: expanded ? 14 : 11,
                    bottomTrailingRadius: expanded ? 14 : 11,
                    topTrailingRadius: 0
                )
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
            }

            if expanded {
                HStack(spacing: 6) {
                    ForEach(ProjectCategory.allCases.filter { $0 != .life }, id: \.self) { category in
                        CategoryButton(category: category) {
                            onHoverCategory(category)
                        }
                    }

                    CombinedLifeConversationButton(onHover: onHoverLifeAndConversations)

                    NextUnreadButton(
                        state: unreadState,
                        refreshing: refreshing,
                        onHover: onHoverNextUnread,
                        onSelect: onOpenNextUnread
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 40, height: 2)
                    .padding(.bottom, 4)
            }
        }
    }
}

private struct NextUnreadButton: View {
    let state: UnreadRefreshState
    let refreshing: Bool
    let onHover: () -> Void
    let onSelect: () -> Void

    private var count: Int { state.threads.count }

    private var refreshedTime: String {
        guard let date = state.lastSuccess else { return "等待刷新" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private var countLabel: String {
        count > 99 ? "99+" : String(count)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(count > 0 ? Color(red: 1.0, green: 0.24, blue: 0.29) : Color.white.opacity(0.20))
                        .frame(width: 17, height: 17)

                    if count > 0 {
                        Text(countLabel)
                            .font(.system(size: count > 9 ? 7 : 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                            .minimumScaleFactor(0.7)
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(state.error == nil ? Color.white.opacity(0.90) : Color.orange)
                    Text(refreshing ? "刷新中" : refreshedTime)
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(count > 0 ? 0.065 : 0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        count > 0
                            ? Color(red: 1.0, green: 0.30, blue: 0.35).opacity(0.38)
                            : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state.error ?? "展开期间每 2 秒重读本地红点。下方为上次成功刷新时间；已清时点击可手动刷新。Codex 尚未保存的提示可能暂未同步。")
        .onHover { inside in
            if inside { onHover() }
        }
    }
}

private struct CategoryButton: View {
    let category: ProjectCategory
    let onHover: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(category.rawValue)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(width: 17, height: 17)
                .background(categoryColor(category), in: RoundedRectangle(cornerRadius: 5))

            Text(category.title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { onHover() }
        }
    }
}

private struct CombinedLifeConversationButton: View {
    let onHover: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text("L")
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(width: 16, height: 16)
                .background(categoryColor(.life), in: RoundedRectangle(cornerRadius: 5))

            Text("生活")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))

            Text("/")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))

            Text("G")
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.88))
                .frame(width: 16, height: 16)
                .background(conversationColor(), in: RoundedRectangle(cornerRadius: 5))

            Text("对话")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { onHover() }
        }
    }
}

struct ProjectDropdownView: View {
    let category: ProjectCategory
    let projects: [CodexProject]
    let markers: [String: ProjectMarker]
    let errorMessage: String?
    let onSelect: (CodexProject) -> Void
    let onSetMarker: (CodexProject, ProjectMarker) -> Void

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0
            )
            .fill(Color.black.opacity(0.975))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 14,
                    topTrailingRadius: 0
                )
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

            ScrollView {
                LazyVStack(spacing: 3) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }

                    ForEach(projects) { project in
                        ProjectRow(
                            project: project,
                            color: categoryColor(category),
                            marker: markers[project.id] ?? .standard,
                            onSelect: { onSelect(project) },
                            onSetMarker: { onSetMarker(project, $0) }
                        )
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.visible)
        }
    }
}

struct LifeConversationDropdownView: View {
    let gNavigationProject: CodexProject?
    let projects: [CodexProject]
    let markers: [String: ProjectMarker]
    let errorMessage: String?
    let onOpenGNavigation: () -> Void
    let onSelect: (CodexProject) -> Void
    let onSetMarker: (CodexProject, ProjectMarker) -> Void

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 14,
                topTrailingRadius: 0
            )
            .fill(Color.black.opacity(0.975))
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 14,
                    topTrailingRadius: 0
                )
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

            ScrollView {
                LazyVStack(spacing: 3) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }

                    if let gNavigationProject {
                        ProjectRow(
                            project: gNavigationProject,
                            color: conversationColor(),
                            marker: markers[gNavigationProject.id] ?? .standard,
                            onSelect: onOpenGNavigation,
                            onSetMarker: { onSetMarker(gNavigationProject, $0) }
                        )
                    } else {
                        GNavigationRow(onSelect: onOpenGNavigation)
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)

                    ForEach(projects) { project in
                        ProjectRow(
                            project: project,
                            color: categoryColor(.life),
                            marker: markers[project.id] ?? .standard,
                            onSelect: { onSelect(project) },
                            onSetMarker: { onSetMarker(project, $0) }
                        )
                    }
                }
                .padding(6)
            }
            .scrollIndicators(.visible)
        }
    }
}

private struct GNavigationRow: View {
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                Text("G")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(conversationColor())
                    .frame(width: 41, alignment: .leading)

                Text("导航")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Spacer(minLength: 4)

                Image(systemName: "folder.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
            .padding(.horizontal, 8)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectRow: View {
    let project: CodexProject
    let color: Color
    let marker: ProjectMarker
    let onSelect: () -> Void
    let onSetMarker: (ProjectMarker) -> Void

    var body: some View {
        let style = projectMarkerStyle(marker, categoryColor: color)

        Button(action: onSelect) {
            HStack(spacing: 7) {
                Text(project.code)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(style.code)
                    .frame(width: 41, alignment: .leading)

                Text(project.name.isEmpty ? project.code : project.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(style.name)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: project.threadID == nil ? "folder" : "bubble.left")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(style.icon)
            }
            .padding(.leading, marker == .standard ? 8 : 13)
            .padding(.trailing, 8)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(style.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(style.border, lineWidth: marker == .standard ? 0.6 : 1.15)
            )
            .overlay(alignment: .leading) {
                if marker != .standard {
                    Capsule()
                        .fill(style.accent)
                        .frame(width: 3, height: 24)
                        .padding(.leading, 5)
                }
            }
            .shadow(color: style.shadow, radius: marker == .standard ? 0 : 2.5, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Section("项目底色") {
                ForEach(ProjectMarker.allCases) { option in
                    Button {
                        onSetMarker(option)
                    } label: {
                        HStack {
                            Label(option.title, systemImage: option.menuSystemImage)
                            if marker == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ProjectMarkerStyle {
    let background: Color
    let hoverBackground: Color
    let border: Color
    let accent: Color
    let code: Color
    let name: Color
    let icon: Color
    let shadow: Color
}

private func projectMarkerStyle(_ marker: ProjectMarker, categoryColor: Color) -> ProjectMarkerStyle {
    switch marker {
    case .standard:
        ProjectMarkerStyle(
            background: Color.white.opacity(0.025),
            hoverBackground: Color.white.opacity(0.095),
            border: Color.white.opacity(0.055),
            accent: categoryColor,
            code: categoryColor,
            name: Color.white.opacity(0.90),
            icon: Color.white.opacity(0.42),
            shadow: .clear
        )
    case .inverted:
        ProjectMarkerStyle(
            background: Color(red: 0.83, green: 0.84, blue: 0.87),
            hoverBackground: Color(red: 0.91, green: 0.92, blue: 0.94),
            border: Color.white.opacity(0.92),
            accent: Color.black.opacity(0.58),
            code: Color.black.opacity(0.78),
            name: Color.black.opacity(0.90),
            icon: Color.black.opacity(0.48),
            shadow: Color.white.opacity(0.14)
        )
    case .red:
        coloredMarkerStyle(
            background: Color(red: 0.38, green: 0.08, blue: 0.12),
            hover: Color(red: 0.48, green: 0.11, blue: 0.16),
            accent: Color(red: 1.00, green: 0.36, blue: 0.42)
        )
    case .orange:
        coloredMarkerStyle(
            background: Color(red: 0.39, green: 0.17, blue: 0.045),
            hover: Color(red: 0.50, green: 0.23, blue: 0.06),
            accent: Color(red: 1.00, green: 0.55, blue: 0.20)
        )
    case .yellow:
        coloredMarkerStyle(
            background: Color(red: 0.34, green: 0.27, blue: 0.035),
            hover: Color(red: 0.44, green: 0.36, blue: 0.05),
            accent: Color(red: 1.00, green: 0.82, blue: 0.18)
        )
    case .green:
        coloredMarkerStyle(
            background: Color(red: 0.055, green: 0.30, blue: 0.19),
            hover: Color(red: 0.07, green: 0.39, blue: 0.25),
            accent: Color(red: 0.30, green: 0.93, blue: 0.59)
        )
    case .blue:
        coloredMarkerStyle(
            background: Color(red: 0.055, green: 0.20, blue: 0.40),
            hover: Color(red: 0.07, green: 0.27, blue: 0.52),
            accent: Color(red: 0.35, green: 0.68, blue: 1.00)
        )
    case .purple:
        coloredMarkerStyle(
            background: Color(red: 0.25, green: 0.10, blue: 0.42),
            hover: Color(red: 0.33, green: 0.14, blue: 0.54),
            accent: Color(red: 0.72, green: 0.46, blue: 1.00)
        )
    }
}

private func coloredMarkerStyle(
    background: Color,
    hover: Color,
    accent: Color
) -> ProjectMarkerStyle {
    ProjectMarkerStyle(
        background: background,
        hoverBackground: hover,
        border: accent.opacity(0.72),
        accent: accent,
        code: accent,
        name: Color.white.opacity(0.96),
        icon: Color.white.opacity(0.60),
        shadow: accent.opacity(0.16)
    )
}

func categoryColor(_ category: ProjectCategory) -> Color {
    switch category {
    case .automation: Color(red: 0.33, green: 0.65, blue: 1.0)
    case .project: Color(red: 0.65, green: 0.55, blue: 1.0)
    case .client: Color(red: 1.0, green: 0.61, blue: 0.33)
    case .life: Color(red: 0.37, green: 0.85, blue: 0.58)
    }
}

func conversationColor() -> Color {
    Color(red: 0.49, green: 0.82, blue: 0.79)
}
