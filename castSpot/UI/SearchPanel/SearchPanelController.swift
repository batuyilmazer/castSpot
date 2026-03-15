import AppKit
import SwiftUI

class SearchPanelController: NSObject {
    private var panel: SearchPanel?

    private let panelWidth: CGFloat = 620
    private let searchBarHeight: CGFloat = 60
    private let rowHeight: CGFloat = 52
    private let resultsPadding: CGFloat = 17   // 8 top + 8 bottom + 1 divider

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onResultsChanged(_:)), name: .resultsCountChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel), name: .closeSearchPanel, object: nil)
    }

    // MARK: - Public Interface

    func toggle() {
        panel?.isVisible == true ? closePanel() : showSearch()
    }

    func showSearch() {
        guard SpotifyAuth.shared.isAuthenticated else { showOnboarding(); return }
        show(content: AnyView(SearchView()), height: searchBarHeight)
    }

    func showOnboarding() {
        show(content: AnyView(OnboardingView(onConnect: { SpotifyAuth.shared.startAuthFlow() })), height: 200)
    }

    @objc func closePanel() {
        panel?.orderOut(nil)
    }

    // MARK: - Panel Construction

    private func show(content: AnyView, height: CGFloat) {
        // Replace existing panel
        if let old = panel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: old)
        }
        panel?.close()

        let p = makePanel(height: height)
        attach(content: content, to: p)
        self.panel = p

        position(p)
        // Activate the app first so the panel can become key
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        p.makeKeyAndOrderFront(nil)
    }

    private func makePanel(height: CGFloat) -> SearchPanel {
        let p = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: height),
            styleMask: [.fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isFloatingPanel = true
        p.becomesKeyOnlyIfNeeded = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePanel),
            name: NSWindow.didResignKeyNotification,
            object: p
        )
        return p
    }

    private func attach(content: AnyView, to panel: NSPanel) {
        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panel.frame.height))
        blur.autoresizingMask = [.width, .height]
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.material = .sidebar
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true

        let hosting = NSHostingView(rootView: content)
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = blur.bounds
        blur.addSubview(hosting)
        panel.contentView = blur
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        let x = sf.midX - panelWidth / 2
        let y = sf.maxY - panel.frame.height - 180
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Dynamic Resize

    @objc private func onResultsChanged(_ note: Notification) {
        guard let count = note.object as? Int, let panel = panel else { return }
        let newHeight = searchBarHeight + (count > 0 ? resultsPadding + CGFloat(count) * rowHeight : 0)
        let oldFrame = panel.frame
        let newFrame = NSRect(x: oldFrame.minX, y: oldFrame.maxY - newHeight, width: panelWidth, height: newHeight)
        guard newFrame != oldFrame else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

}
