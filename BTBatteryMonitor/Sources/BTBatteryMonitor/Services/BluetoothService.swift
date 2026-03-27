import Foundation
import IOBluetooth
import Combine

@MainActor
final class BluetoothService: NSObject, ObservableObject {
    @Published var devices: [BluetoothDevice] = []

    private let battery = BatteryService()
    private var connectNotification: IOBluetoothUserNotification?
    private var pollingTimer: Timer?

    // DISC-03: start connect/disconnect monitoring
    func startMonitoring() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        refresh()
        schedulePolling()
    }

    // Poll every 60 seconds (Claude discretion: UI-SPEC polling contract)
    private func schedulePolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    // DISC-01 + BATT-01: enumerate connected devices and merge battery data
    func refresh() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let batteryMap = self.battery.fetchBatteryLevels()  // background IOKit call
            await MainActor.run {
                self.devices = self.buildDeviceList(batteryMap: batteryMap)
            }
        }
    }

    // DISC-01, DISC-02, BATT-04: build sorted device list
    private func buildDeviceList(batteryMap: [String: Int]) -> [BluetoothDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        let connected = paired.filter { $0.isConnected() }
        let deviceList: [BluetoothDevice] = connected.map { device in
            // Pitfall 3: multi-source name resolution
            let name = device.name ?? "알 수 없는 장치"
            let type = DeviceType.from(classOfDevice: UInt32(device.classOfDevice))
            // Match IOKit battery by name (best-effort — Product key may differ from IOBluetooth name)
            let battery = batteryMap[name]
            return BluetoothDevice(name: name, type: type, batteryPercent: battery, isConnected: true)
        }
        return deviceList.sorted()   // BluetoothDevice.Comparable: battery ascending, nil last (D-03/D-04)
    }

    // DISC-03: new device connected
    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification,
                                        device: IOBluetoothDevice) {
        device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
        refresh()
    }

    // DISC-03: device disconnected
    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification,
                                           device: IOBluetoothDevice) {
        refresh()
    }
}
