import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothService: BluetoothService
    private var eventMonitor: Any?

    init(bluetoothService: BluetoothService) {
        self.bluetoothService = bluetoothService

        // Create NSStatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bluetooth",
                                   accessibilityDescription: "BT Battery Monitor — 배터리 상태 표시")
            button.title = "--"   // loading state per Copywriting Contract
            button.imagePosition = .imageLeft
        }

        // Create NSPopover with SwiftUI content (UI-03)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(bluetoothService)
        )

        // Wire button action
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.target = self

        // Observe devices changes to update status bar text/icon
        bluetoothService.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                self?.updateStatusItem(devices: devices)
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            closePopover()
        } else {
            // Refresh before showing popover (UI-SPEC interaction contract)
            bluetoothService.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            Task { @MainActor in self.closePopover() }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func updateStatusItem(devices: [BluetoothDevice]) {
        guard let button = statusItem.button else { return }

        let withBattery = devices.filter { $0.batteryPercent != nil }

        if withBattery.isEmpty {
            // No devices with battery data — show "BT" text so item is always identifiable
            button.image = NSImage(systemSymbolName: "battery.0",
                                   accessibilityDescription: "BT Battery Monitor — 배터리 상태 표시")
            button.title = "BT"
            button.imagePosition = .imageLeft
            return
        }

        // Lowest battery device drives status item display (UI-01)
        let lowest = withBattery.map { $0.batteryPercent! }.min()!
        button.title = "\(lowest)%"

        // Icon selection logic per UI-SPEC Component 1
        let (symbolName, tintColor): (String, NSColor?) = {
            if lowest < 30 { return ("battery.25", .systemRed) }
            if lowest < 70 { return ("battery.50", nil) }
            return ("battery.100", nil)
        }()

        if let tintColor {
            let config = NSImage.SymbolConfiguration(paletteColors: [tintColor])
            button.image = NSImage(systemSymbolName: symbolName,
                                   accessibilityDescription: "BT Battery Monitor — 배터리 상태 표시")?
                .withSymbolConfiguration(config)
        } else {
            button.image = NSImage(systemSymbolName: symbolName,
                                   accessibilityDescription: "BT Battery Monitor — 배터리 상태 표시")
        }
        button.imagePosition = .imageLeft
    }
}
