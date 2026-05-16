import AppKit
import Foundation

@MainActor
enum AppWindowPresenter {
    static func activate() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    static func showSettings(openSettings: @escaping () -> Void) {
        activate()
        openSettings()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activate()
            bringVisibleWindowsForward()
        }
    }

    static func bringVisibleWindowsForward() {
        for window in NSApplication.shared.windows where window.isVisible {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
