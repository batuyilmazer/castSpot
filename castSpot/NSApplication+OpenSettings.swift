//
//  NSApplication+OpenSettings.swift
//  Opens SwiftUI Settings scene from AppKit (e.g. status bar menu).
//  macOS 14+ requires using the Settings menu item's action instead of showSettingsWindow:.
//

import AppKit

private let kAppMenuInternalIdentifier = "app"
private let kSettingsLocalizedStringKey = "Settings\u{2026}"

extension NSApplication {

    /// Opens the application Settings window by invoking the SwiftUI-registered Settings menu action.
    /// Use this from AppKit (e.g. NSMenuItem) when running on macOS 14+.
    func openSettings() {
        if let action = mainMenu?.item(withInternalIdentifier: kAppMenuInternalIdentifier)?
            .submenu?
            .item(withLocalizedTitle: kSettingsLocalizedStringKey)?
            .internalItemAction {
            action()
            activate(ignoringOtherApps: true)
            return
        }

        if let delegate = delegate as? NSObject, delegate.responds(to: Selector(("showSettingsWindow:"))) {
            delegate.perform(Selector(("showSettingsWindow:")), with: nil, with: nil)
            activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - NSMenuItem (Private helpers for SwiftUI menu structure)

private extension NSMenuItem {

    var internalIdentifier: String? {
        guard let id = Mirror.firstChild(withLabel: "id", in: self)?.value else { return nil }
        return "\(id)"
    }

    var internalItemAction: (() -> Void)? {
        guard
            let platformItemAction = Mirror.firstChild(withLabel: "platformItemAction", in: self)?.value,
            let typeErasedCallback = Mirror.firstChild(in: platformItemAction)?.value
        else { return nil }
        return Mirror.firstChild(in: typeErasedCallback)?.value as? () -> Void
    }
}

// MARK: - NSMenu (Private helpers)

private extension NSMenu {

    func item(withInternalIdentifier identifier: String) -> NSMenuItem? {
        items.first { $0.internalIdentifier == identifier }
    }

    func item(
        withLocalizedTitle localizedTitleKey: String,
        inTable tableName: String = "MenuCommands",
        fromBundle bundlePath: String = "/System/Library/Frameworks/AppKit.framework"
    ) -> NSMenuItem? {
        guard let bundle = Bundle(path: bundlePath) else { return nil }
        let title = NSLocalizedString(localizedTitleKey, tableName: tableName, bundle: bundle, comment: "")
        return items.first { $0.title == title }
    }
}

// MARK: - Mirror (Helper)

private extension Swift.Mirror {

    var firstChild: Child? { children.first }

    func firstChild(withLabel label: String) -> Child? {
        children.first { $0.label == label }
    }

    static func firstChild(in subject: Any) -> Child? {
        Swift.Mirror(reflecting: subject).firstChild
    }

    static func firstChild(withLabel label: String, in subject: Any) -> Child? {
        Swift.Mirror(reflecting: subject).firstChild(withLabel: label)
    }
}
