import SwiftUI
import Carbon.HIToolbox
import AppKit

// MARK: - KeyRecorderNSView

private final class KeyRecorderNSView: NSView {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

// MARK: - KeyRecorderView

private struct KeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let label: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let recorder = KeyRecorderNSView()
        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.onMouseDown = { [coordinator = context.coordinator] in
            coordinator.startRecording()
        }
        context.coordinator.recorder = recorder

        let text = NSTextField(labelWithString: label)
        text.translatesAutoresizingMaskIntoConstraints = false
        text.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        text.alignment = .center
        text.isSelectable = false
        context.coordinator.textField = text

        recorder.addSubview(text)
        container.addSubview(recorder)

        NSLayoutConstraint.activate([
            recorder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            recorder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            recorder.topAnchor.constraint(equalTo: container.topAnchor),
            recorder.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            text.centerXAnchor.constraint(equalTo: recorder.centerXAnchor),
            text.centerYAnchor.constraint(equalTo: recorder.centerYAnchor),
        ])
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isRecordingBinding = $isRecording
        context.coordinator.textField?.stringValue = isRecording ? "recording…" : label
        context.coordinator.textField?.textColor = isRecording ? .systemRed : .secondaryLabelColor
    }

    class Coordinator: NSObject {
        // Static weak ref so the @convention(c) CGEventTap callback can reach the active coordinator
        nonisolated(unsafe) static weak var activeRecording: Coordinator?

        var isRecordingBinding: Binding<Bool> = .constant(false)
        weak var recorder: KeyRecorderNSView?
        weak var textField: NSTextField?
        private var localMonitor: Any?
        private var eventTap: CFMachPort?
        private var tapRunLoopSource: CFRunLoopSource?

        func startRecording() {
            guard localMonitor == nil, eventTap == nil else { return }
            Coordinator.activeRecording = self
            isRecordingBinding.wrappedValue = true

            // If Accessibility is not yet granted, prompt the user and fall back to local monitor only.
            // After granting, the user must click the recorder again.
            if !AXIsProcessTrusted() {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(opts)
            }

            // CGEventTap: operates before WindowServer, catches system shortcuts (requires Accessibility)
            if AXIsProcessTrusted() {
                let tapCB: CGEventTapCallBack = { _, type, event, _ in
                    guard type == .keyDown,
                          let c = Coordinator.activeRecording else {
                        return Unmanaged.passRetained(event)
                    }
                    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                    if keyCode == 53 { // Escape
                        DispatchQueue.main.async { c.stopRecording() }
                        return nil
                    }
                    let f = event.flags
                    var mods = NSEvent.ModifierFlags()
                    if f.contains(.maskControl) { mods.insert(.control) }
                    if f.contains(.maskCommand) { mods.insert(.command) }
                    if f.contains(.maskAlternate) { mods.insert(.option) }
                    if f.contains(.maskShift) { mods.insert(.shift) }
                    guard !mods.isEmpty else { return Unmanaged.passRetained(event) }
                    DispatchQueue.main.async { c.recordKey(keyCode: keyCode, flags: mods) }
                    return nil
                }
                // .cgHIDEventTap fires before system shortcut processing (Spotlight, Input Sources etc.)
                // .cgSessionEventTap fires AFTER — that's why Control+Space was missed.
                // Falls back to nil (local monitor handles the rest) if HID tap isn't allowed.
                if let tap = CGEvent.tapCreate(
                    tap: CGEventTapLocation(rawValue: 0)!, // kCGHIDEventTap — before system shortcuts
                    place: .headInsertEventTap,
                    options: .defaultTap,
                    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
                    callback: tapCB,
                    userInfo: nil
                ) {
                    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                    CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
                    CGEvent.tapEnable(tap: tap, enable: true)
                    eventTap = tap
                    tapRunLoopSource = src
                }
            }

            // Local monitor: fallback for non-system shortcuts (no Accessibility needed)
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 53 { self.stopRecording(); return nil }
                let mods = event.modifierFlags.intersection([.control, .command, .option, .shift])
                guard !mods.isEmpty else { return event }
                self.recordKey(keyCode: event.keyCode, flags: mods)
                return nil
            }

        }

        func stopRecording() {
            removeMonitors()
            isRecordingBinding.wrappedValue = false
        }

        func recordKey(keyCode: UInt16, flags: NSEvent.ModifierFlags) {
            removeMonitors()
            let carbonMods = carbonModifiers(from: flags)
            UserDefaults.standard.set(Int(keyCode), forKey: HotKey.codeKey)
            UserDefaults.standard.set(Int(carbonMods), forKey: HotKey.modifiersKey)
            AppDelegate.shared?.reregisterHotKey()
            isRecordingBinding.wrappedValue = false
        }

        private func removeMonitors() {
            Coordinator.activeRecording = nil
            if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: false)
                if let src = tapRunLoopSource {
                    CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                    tapRunLoopSource = nil
                }
                eventTap = nil
            }
        }

        deinit { removeMonitors() }
    }
}

// MARK: - Helpers

private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var result: UInt32 = 0
    if flags.contains(.control) { result |= UInt32(controlKey) }
    if flags.contains(.command) { result |= UInt32(cmdKey) }
    if flags.contains(.option)  { result |= UInt32(optionKey) }
    if flags.contains(.shift)   { result |= UInt32(shiftKey) }
    return result
}

private func shortcutLabel(keyCode: Int, modifiers: Int) -> String {
    var label = ""
    if modifiers & controlKey != 0 { label += "⌃" }
    if modifiers & optionKey  != 0 { label += "⌥" }
    if modifiers & shiftKey   != 0 { label += "⇧" }
    if modifiers & cmdKey     != 0 { label += "⌘" }

    let specialKeys: [Int: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "⌫", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        131: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    if let name = specialKeys[keyCode] {
        label += name
    } else {
        // Use UCKeyTranslate to get the key character for the current keyboard layout
        if let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let dataRef = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue()
            let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(dataRef), to: UnsafePointer<UCKeyboardLayout>.self)
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            UCKeyTranslate(keyboardLayout, UInt16(keyCode), UInt16(kUCKeyActionDisplay),
                           0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                           &deadKeyState, 4, &length, &chars)
            if length > 0 {
                label += String(chars[0]).uppercased()
            }
        }
    }
    return label
}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject var auth: SpotifyAuth
    @State private var isRecording = false
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @AppStorage(HotKey.codeKey) private var hotKeyCode: Int = 0
    @AppStorage(HotKey.modifiersKey) private var hotKeyModifiers: Int = 0
    @AppStorage(PanelPosition.defaultsKey) private var panelPosition: PanelPosition = .topCenter

    private var currentLabel: String {
        let code = hotKeyCode == 0 ? HotKey.defaultCode : hotKeyCode
        let mods = hotKeyModifiers == 0 ? HotKey.defaultModifiers : hotKeyModifiers
        return shortcutLabel(keyCode: code, modifiers: mods)
    }

    var body: some View {
        Form {
            Section("Spotify Account") {
                if auth.isAuthenticated {
                    HStack(spacing: 12) {
                        if let url = auth.currentUser?.profileImageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(.quaternary)
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(.quaternary)
                                .frame(width: 36, height: 36)
                                .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = auth.currentUser?.displayName {
                                Text(name).fontWeight(.medium)
                            } else {
                                Text("Connected").foregroundStyle(.secondary)
                            }
                            Text("Spotify")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Disconnect") { auth.signOut() }
                            .foregroundStyle(.red)
                    }
                } else {
                    HStack {
                        Label("Not connected", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Connect Spotify") { auth.startAuthFlow() }
                    }
                }
            }

            Section("Keyboard Shortcut") {
                if !isAccessibilityTrusted {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Accessibility access is required to capture system shortcuts like ⌃Space. Grant it in **System Settings → Privacy & Security → Accessibility**, then relaunch castSpot.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
                LabeledContent("Show castSpot") {
                    HStack(spacing: 8) {
                        KeyRecorderView(isRecording: $isRecording, label: currentLabel)
                            .frame(width: 100, height: 22)
                        Button("Reset") {
                            UserDefaults.standard.removeObject(forKey: HotKey.codeKey)
                            UserDefaults.standard.removeObject(forKey: HotKey.modifiersKey)
                            hotKeyCode = 0
                            hotKeyModifiers = 0
                            AppDelegate.shared?.reregisterHotKey()
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Search Panel") {
                Picker("Position", selection: $panelPosition) {
                    ForEach(PanelPosition.allCases, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Link("GitHub", destination: URL(string: "https://github.com/batuyilmazer/castSpot")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: isAccessibilityTrusted ? 410 : 490)
    }
}
