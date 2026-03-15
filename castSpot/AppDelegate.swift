import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    var panelController: SearchPanelController?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    // nonisolated(unsafe) so C callback can access without actor isolation
    nonisolated(unsafe) static var onHotKey: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        panelController = SearchPanelController()
        registerHotKey()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenURL(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        if !SpotifyAuth.shared.isAuthenticated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.panelController?.showOnboarding()
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "castSpot")
        statusItem?.button?.action = #selector(showMenu)
        statusItem?.button?.target = self
    }

    @objc private func showMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open castSpot", action: #selector(togglePanel), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        if SpotifyAuth.shared.isAuthenticated {
            let disconnectItem = NSMenuItem(title: "Disconnect Spotify", action: #selector(disconnectSpotify), keyEquivalent: "")
            disconnectItem.target = self
            menu.addItem(disconnectItem)
        } else {
            let connectItem = NSMenuItem(title: "Connect Spotify", action: #selector(connectSpotify), keyEquivalent: "")
            connectItem.target = self
            menu.addItem(connectItem)
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit castSpot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func togglePanel() {
        panelController?.toggle()
    }

    @objc private func connectSpotify() { SpotifyAuth.shared.startAuthFlow() }
    @objc private func disconnectSpotify() { SpotifyAuth.shared.signOut() }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - URL Callback (OAuth)

    @objc func handleOpenURL(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard
            let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }
        SpotifyAuth.shared.handleCallback(url: url)
    }

    // MARK: - Global HotKey via Carbon (no Accessibility permission needed)

    private func registerHotKey() {
        let defaults = UserDefaults.standard
        // Default: Control+Space (kVK_Space=49, controlKey=4096)
        let rawKeyCode = defaults.integer(forKey: "hotKeyCode")
        let keyCode = UInt32(rawKeyCode == 0 ? 49 : rawKeyCode)
        let rawModifiers = defaults.integer(forKey: "hotKeyModifiers")
        let modifiers = UInt32(rawModifiers == 0 ? 4096 : rawModifiers)

        AppDelegate.onHotKey = { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                DispatchQueue.main.async { AppDelegate.onHotKey?() }
                return noErr
            },
            1, &spec, nil, &eventHandlerRef
        )

        // Signature "csSp" as UInt32
        let hotKeyID = EventHotKeyID(signature: 0x6373_5370, id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func reregisterHotKey() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
        registerHotKey()
    }
}
