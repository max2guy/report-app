import AppKit
import SwiftUI

/// NSPanel 기반 설정 창 컨트롤러.
/// RESEARCH.md Pattern 5: SettingsLink는 LSUIElement 앱에서 신뢰 불가 — NSPanel 직접 사용.
/// Pitfall 3: .regular activation policy 전환으로 창이 front에 표시됨.
@MainActor
final class SettingsController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    // weak ref to BluetoothService for passing to SettingsView
    weak var bluetoothService: BluetoothService?

    func showSettings() {
        if let panel, panel.isVisible {
            panel.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard let service = bluetoothService else { return }
        let settingsView = SettingsView(bluetoothService: service)
        let hosting = NSHostingController(rootView: settingsView)
        let p = NSPanel(contentViewController: hosting)
        p.title = "BT Battery Monitor 설정"
        p.styleMask = [.titled, .closable, .resizable]
        p.isReleasedWhenClosed = false
        p.setContentSize(NSSize(width: 320, height: 200))
        p.center()
        p.delegate = self
        self.panel = p
        // Pitfall 3: .regular → foreground 전환 필요
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    // NSWindowDelegate: 창 닫힐 때 .accessory 복원 (Open Question 2)
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
