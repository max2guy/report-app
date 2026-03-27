import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var bluetoothService: BluetoothService?
    // Optional — initialized on main thread in applicationDidFinishLaunching
    private var settingsController: SettingsController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LIFE-02: no Dock icon — also set via LSUIElement in Info.plist (belt + suspenders)
        NSApp.setActivationPolicy(.accessory)

        MainActor.assumeIsolated {
            let service = BluetoothService()
            bluetoothService = service
            let sc = SettingsController()
            sc.bluetoothService = service
            settingsController = sc
            statusBarController = StatusBarController(bluetoothService: service)
            service.startMonitoring()
        }

        // HeaderView 버튼에서 NotificationCenter로 호출 — SettingsController를 View에 직접 주입하지 않는 방식
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsPanel(_:)),
            name: Notification.Name("OpenSettings"),
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        statusBarController = nil
        bluetoothService = nil
        settingsController = nil
    }

    @objc func openSettingsPanel(_ sender: Any?) {
        guard let sc = settingsController else { return }
        Task { @MainActor in
            sc.showSettings()
        }
    }
}
