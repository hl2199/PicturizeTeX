import AppKit
import SwiftUI

/// Drops the Dock icon while no main window is open, so the menu bar
/// companion can carry on alone, and restores it when a window returns.
///
/// Main windows are counted from ContentView's appear/disappear rather than
/// read off NSApp.windows, which also holds the menu bar panel and the
/// exporter's offscreen host windows.
@MainActor
enum DockPolicy {
    static let mainWindowID = "main"
    static let hideDockKey = "hideDockWhenWindowClosed"

    private static var openMainWindows = 0

    static func mainWindowAppeared() {
        openMainWindows += 1
        NSApp.setActivationPolicy(.regular)
    }

    static func mainWindowDisappeared() {
        openMainWindows = max(0, openMainWindows - 1)
        guard openMainWindows == 0 else { return }

        let defaults = UserDefaults.standard
        let menuBarShown = defaults.bool(forKey: "showMenuBarExtra")
        let hideDock = defaults.object(forKey: hideDockKey) as? Bool ?? true
        if menuBarShown && hideDock {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    /// Brings the main window forward, opening one if none is open.
    static func showMainWindow(using openWindow: OpenWindowAction) {
        if openMainWindows == 0 {
            openWindow(id: mainWindowID)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
