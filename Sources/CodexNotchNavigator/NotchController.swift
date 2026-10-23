import AppKit
import CodexNotchCore
import SwiftUI

final class OverlayPanel: NSPanel {
    var onRightClick: (() -> Void)?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .rightMouseDown,
              onRightClick != nil,
              let contentView
        else {
            super.sendEvent(event)
            return
        }

        let menu = NSMenu()
        let closeItem = NSMenuItem(
            title: "关闭导航台",
            action: #selector(closeNavigator),
            keyEquivalent: ""
        )
        closeItem.target = self
        closeItem.image = NSImage(
            systemSymbolName: "xmark.circle",
            accessibilityDescription: "关闭导航台"
        )
        menu.addItem(closeItem)
        NSMenu.popUpContextMenu(menu, with: event, for: contentView)
    }

    @objc private func closeNavigator() {
        onRightClick?()
    }
}

private enum NavigationTarget: Equatable {
    case projects(ProjectCategory)
    case lifeAndConversations
}

private struct NavigationSnapshot: Sendable {
    let projects: [CodexProject]?
    let unread: [UnreadThread]?
    let error: String?
}

@MainActor
final class NotchController {
    private let projectStore: ProjectStore
    private let unreadThreadStore: UnreadThreadStore
    private let launcher: CodexLauncher
    private let markerStore: ProjectMarkerStore

    private var projects: [CodexProject] = []
    private var unreadState = UnreadRefreshState()
    private var refreshing = false
    private var openWhenRefreshed = false
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var lastOpenedUnreadID: String?
    private var topPanel: OverlayPanel!
    private var dropdownPanel: OverlayPanel!
    private var topHostingView: NSHostingView<TopRailView>!
    private var dropdownHostingView: NSHostingView<AnyView>!
    private var mouseTimer: Timer?
    private var outsideSince: TimeInterval?
    private var activeTarget: NavigationTarget?
    private var currentScreen: NSScreen?
    private var expanded = false

    init(
        projectStore: ProjectStore = ProjectStore(),
        unreadThreadStore: UnreadThreadStore = UnreadThreadStore(),
        launcher: CodexLauncher = CodexLauncher(),
        markerStore: ProjectMarkerStore = ProjectMarkerStore()
    ) {
        self.projectStore = projectStore
        self.unreadThreadStore = unreadThreadStore
        self.launcher = launcher
        self.markerStore = markerStore
    }

    func start() {
        createPanels()
        reloadNavigationData()
        moveCollapsedPanel(to: screenForMouse() ?? NSScreen.main)
        topPanel.orderFrontRegardless()

        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollMouse() }
        }
        RunLoop.main.add(mouseTimer!, forMode: .common)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.expanded else { return }
                self.reloadNavigationData()
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.moveCollapsedPanel(to: self?.screenForMouse() ?? NSScreen.main) }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        refreshTask?.cancel()
        mouseTimer?.invalidate()
        mouseTimer = nil
        topPanel?.orderOut(nil)
        dropdownPanel?.orderOut(nil)
    }

    private func createPanels() {
        topPanel = makePanel(shadow: true)
        dropdownPanel = makePanel(shadow: true)
        topPanel.onRightClick = {
            NSApplication.shared.terminate(nil)
        }

        topHostingView = NSHostingView(rootView: makeTopView(expanded: false))
        topHostingView.wantsLayer = true
        topHostingView.layer?.backgroundColor = NSColor.clear.cgColor
        topPanel.contentView = topHostingView

        dropdownHostingView = NSHostingView(
            rootView: AnyView(ProjectDropdownView(
                category: .automation,
                projects: [],
                markers: [:],
                errorMessage: nil,
                onSelect: { _ in },
                onSetMarker: { _, _ in }
            ))
        )
        dropdownHostingView.wantsLayer = true
        dropdownHostingView.layer?.backgroundColor = NSColor.clear.cgColor
        dropdownPanel.contentView = dropdownHostingView
    }

    private func makePanel(shadow: Bool) -> OverlayPanel {
        let panel = OverlayPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = shadow
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        return panel
    }

    private func makeTopView(expanded: Bool) -> TopRailView {
        TopRailView(
            expanded: expanded,
            unreadState: unreadState,
            refreshing: refreshing,
            onHoverCategory: { [weak self] category in
                self?.showProjectDropdown(for: category)
            },
            onHoverLifeAndConversations: { [weak self] in
                self?.showLifeAndConversationDropdown()
            },
            onHoverNextUnread: { [weak self] in
                self?.hideDropdownForDirectAction()
            },
            onOpenNextUnread: { [weak self] in
                self?.openNextUnreadThread()
            }
        )
    }

    private func reloadNavigationData() {
        guard !refreshing else { return }
        refreshing = true
        topHostingView.rootView = makeTopView(expanded: expanded)
        let projectStateURL = projectStore.stateURL
        let projectDatabaseURL = projectStore.databaseURL
        let unreadStateURL = unreadThreadStore.stateURL
        let unreadDatabaseURL = unreadThreadStore.databaseURL
        refreshTask = Task { [weak self] in
            let snapshot = await Task.detached(priority: .utility) {
                let loadedProjects = try? ProjectStore(stateURL: projectStateURL, databaseURL: projectDatabaseURL).loadProjects()
                do {
                    let unread = try UnreadThreadStore(stateURL: unreadStateURL, databaseURL: unreadDatabaseURL).loadUnreadThreads()
                    return NavigationSnapshot(projects: loadedProjects, unread: unread, error: nil)
                } catch {
                    return NavigationSnapshot(projects: loadedProjects, unread: nil, error: error.localizedDescription)
                }
            }.value
            guard !Task.isCancelled, let self else { return }
            if let projects = snapshot.projects { self.projects = projects }
            if let unread = snapshot.unread {
                self.unreadState.receive(unread)
                UserDefaults.standard.set(Date(), forKey: "lastUnreadRefreshAt")
                UserDefaults.standard.set(unread.count, forKey: "lastUnreadRefreshCount")
            } else {
                self.unreadState.fail(snapshot.error ?? "读取失败，请重试")
            }
            self.refreshing = false
            self.topHostingView.rootView = self.makeTopView(expanded: self.expanded)
            if self.expanded, let target = self.activeTarget { self.showDropdown(for: target) }
            let shouldOpen = self.openWhenRefreshed
            self.openWhenRefreshed = false
            if shouldOpen, snapshot.unread != nil { self.openLoadedUnreadThread() }
        }
    }

    private func pollMouse() {
        let point = NSEvent.mouseLocation

        if !expanded {
            guard let screen = screenForPoint(point) ?? currentScreen ?? NSScreen.main else { return }
            let trigger = collapsedFrame(on: screen).insetBy(dx: -10, dy: -5)
            if trigger.contains(point) {
                expand(on: screen)
            }
            return
        }

        let overTop = topPanel.frame.insetBy(dx: -2, dy: -2).contains(point)
        let overDropdown = dropdownPanel.isVisible && dropdownPanel.frame.insetBy(dx: -2, dy: -2).contains(point)

        if overTop,
           let hoveredTarget = navigationTarget(at: point),
           hoveredTarget != activeTarget
        {
            showDropdown(for: hoveredTarget)
        }

        if overTop || overDropdown {
            outsideSince = nil
        } else if outsideSince == nil {
            outsideSince = ProcessInfo.processInfo.systemUptime
        } else if ProcessInfo.processInfo.systemUptime - (outsideSince ?? 0) >= 0.48 {
            collapse()
        }
    }

    private func expand(on screen: NSScreen) {
        reloadNavigationData()
        currentScreen = screen
        expanded = true
        outsideSince = nil
        topHostingView.rootView = makeTopView(expanded: true)
        topPanel.setFrame(expandedFrame(on: screen), display: true, animate: true)
        topPanel.orderFrontRegardless()
    }

    private func collapse() {
        guard expanded else { return }
        expanded = false
        activeTarget = nil
        outsideSince = nil
        dropdownPanel.orderOut(nil)
        topHostingView.rootView = makeTopView(expanded: false)
        if let screen = currentScreen ?? NSScreen.main {
            topPanel.setFrame(collapsedFrame(on: screen), display: true, animate: true)
        }
    }

    private func showDropdown(for target: NavigationTarget) {
        switch target {
        case let .projects(category):
            showProjectDropdown(for: category)
        case .lifeAndConversations:
            showLifeAndConversationDropdown()
        }
    }

    private func showProjectDropdown(for category: ProjectCategory, errorMessage: String? = nil) {
        guard expanded, let screen = currentScreen ?? NSScreen.main else { return }
        activeTarget = .projects(category)
        let matching = projects.filter { $0.category == category }

        dropdownHostingView.rootView = AnyView(ProjectDropdownView(
            category: category,
            projects: matching,
            markers: markerStore.markers,
            errorMessage: errorMessage,
            onSelect: { [weak self] project in
                self?.openProject(project)
            },
            onSetMarker: { [weak self] project, marker in
                self?.setMarker(marker, for: project)
            }
        ))

        dropdownPanel.setFrame(
            dropdownFrame(on: screen, slotOrder: category.order, count: matching.count),
            display: true
        )
        dropdownPanel.orderFrontRegardless()
    }

    private func showLifeAndConversationDropdown(errorMessage: String? = nil) {
        guard expanded, let screen = currentScreen ?? NSScreen.main else { return }
        activeTarget = .lifeAndConversations
        let gNavigationProject = projects.first { $0.code == "G" }
        let lifeProjects = projects.filter { $0.category == .life && $0.code != "G" }

        dropdownHostingView.rootView = AnyView(LifeConversationDropdownView(
            gNavigationProject: gNavigationProject,
            projects: lifeProjects,
            markers: markerStore.markers,
            errorMessage: errorMessage,
            onOpenGNavigation: { [weak self] in
                guard let self else { return }
                guard let gNavigationProject else {
                    self.showLifeAndConversationDropdown(errorMessage: "没有找到 G 导航项目。")
                    return
                }
                self.openProject(gNavigationProject)
            },
            onSelect: { [weak self] project in
                self?.openProject(project)
            },
            onSetMarker: { [weak self] project, marker in
                self?.setMarker(marker, for: project)
            }
        ))

        dropdownPanel.setFrame(
            dropdownFrame(on: screen, slotOrder: 3, count: lifeProjects.count + 1),
            display: true
        )
        dropdownPanel.orderFrontRegardless()
    }

    private func openProject(_ project: CodexProject) {
        do {
            try launcher.open(project: project)
            collapse()
        } catch {
            if project.category == .life {
                showLifeAndConversationDropdown(errorMessage: error.localizedDescription)
            } else {
                showProjectDropdown(for: project.category, errorMessage: error.localizedDescription)
            }
        }
    }

    private func hideDropdownForDirectAction() {
        activeTarget = nil
        dropdownPanel.orderOut(nil)
    }

    private func openNextUnreadThread() {
        // An empty or failed state makes this a refresh button, not a navigation action.
        openWhenRefreshed = unreadState.error == nil && !unreadState.threads.isEmpty
        reloadNavigationData()
    }

    private func openLoadedUnreadThread() {
        guard let target = UnreadThreadStore.nextUnreadThread(
            in: unreadState.threads,
            after: lastOpenedUnreadID
        ) else {
            return
        }

        do {
            try launcher.open(threadID: target.id)
            lastOpenedUnreadID = target.id
            collapse()
        } catch {
            unreadState.fail(error.localizedDescription)
            topHostingView.rootView = makeTopView(expanded: expanded)
        }
    }

    private func setMarker(_ marker: ProjectMarker, for project: CodexProject) {
        markerStore.set(marker, for: project.id)
        if project.category == .life {
            showLifeAndConversationDropdown()
        } else {
            showProjectDropdown(for: project.category)
        }
    }

    private func moveCollapsedPanel(to screen: NSScreen?) {
        guard !expanded, let screen else { return }
        currentScreen = screen
        topPanel?.setFrame(collapsedFrame(on: screen), display: true)
    }

    private func screenForMouse() -> NSScreen? {
        screenForPoint(NSEvent.mouseLocation)
    }

    private func screenForPoint(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private func navigationTarget(at point: NSPoint) -> NavigationTarget? {
        let frame = topPanel.frame
        let innerMinX = frame.minX + 10
        let innerWidth = frame.width - 20
        let buttonWidth = (innerWidth - 24) / 5
        let slotWidth = buttonWidth + 6
        let offset = point.x - innerMinX
        guard offset >= 0 else { return nil }

        let index = Int(offset / slotWidth)
        guard (0 ..< 5).contains(index) else { return nil }

        let offsetInSlot = offset - CGFloat(index) * slotWidth
        guard offsetInSlot <= buttonWidth else { return nil }

        switch index {
        case 0:
            return .projects(.automation)
        case 1:
            return .projects(.project)
        case 2:
            return .projects(.client)
        case 3:
            return .lifeAndConversations
        case 4:
            return nil
        default:
            return nil
        }
    }

    private func collapsedFrame(on screen: NSScreen) -> NSRect {
        let topInset = max(screen.safeAreaInsets.top, 28)
        let notchWidth: CGFloat
        let notchOriginX: CGFloat

        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           right.minX > left.maxX
        {
            notchWidth = right.minX - left.maxX
            notchOriginX = left.maxX
        } else {
            notchWidth = 166
            notchOriginX = screen.frame.midX - notchWidth / 2
        }

        return NSRect(
            x: notchOriginX,
            y: screen.frame.maxY - topInset,
            width: notchWidth,
            height: topInset
        )
    }

    private func expandedFrame(on screen: NSScreen) -> NSRect {
        let width = min(640, screen.frame.width - 32)
        let height: CGFloat = 54
        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    private func dropdownFrame(on screen: NSScreen, slotOrder: Int, count: Int) -> NSRect {
        let top = expandedFrame(on: screen)
        let width: CGFloat = 224
        let availableHeight = max(80, top.minY - screen.visibleFrame.minY - 8)
        let rowCount = max(count, 1)
        let contentHeight = CGFloat(rowCount * 40 + max(rowCount - 1, 0) * 3 + 12)
        let height = min(456, availableHeight, contentHeight)

        let innerWidth = top.width - 20
        let categoryWidth = (innerWidth - 24) / 5
        let centerX = top.minX + 10 + CGFloat(slotOrder) * (categoryWidth + 6) + categoryWidth / 2
        let unclampedX = centerX - width / 2
        let x = min(max(unclampedX, screen.frame.minX + 8), screen.frame.maxX - width - 8)

        return NSRect(x: x, y: top.minY - height, width: width, height: height)
    }
}
