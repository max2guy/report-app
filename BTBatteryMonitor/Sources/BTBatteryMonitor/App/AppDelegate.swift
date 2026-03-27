import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var bluetoothService: BluetoothService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LIFE-02: no Dock icon — also set via LSUIElement in Info.plist (belt + suspenders)
        NSApp.setActivationPolicy(.accessory)

        let service = BluetoothService()
        bluetoothService = service
        statusBarController = StatusBarController(bluetoothService: service)
        service.startMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController = nil
        bluetoothService = nil
    }
}
