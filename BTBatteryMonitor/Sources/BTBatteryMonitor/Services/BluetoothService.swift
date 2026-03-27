import Foundation
import IOBluetooth
import Combine

@MainActor
final class BluetoothService: NSObject, ObservableObject {
    @Published var devices: [BluetoothDevice] = []

    private let battery = BatteryService()
    private let bleService = BLEService()
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

    // BATT-03: Poll using PollingInterval (default 5 minutes). Pitfall 6: invalidate before rescheduling.
    private func schedulePolling(interval: PollingInterval = DevicePreferences.shared.pollingInterval) {
        pollingTimer?.invalidate()  // Pitfall 6: 중복 타이머 방지
        pollingTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval.rawValue), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    /// 폴링 간격 변경 + 즉시 재스케줄링 (MGMT-03)
    func updatePollingInterval(_ interval: PollingInterval) {
        DevicePreferences.shared.pollingInterval = interval
        schedulePolling(interval: interval)
    }

    // DISC-01 + BATT-01 + BATT-02: enumerate connected devices and merge IOKit + HID + BLE battery data
    func refresh() {
        // Capture @MainActor-isolated properties before entering Task.detached (Swift 5.x actor isolation)
        let batteryService = self.battery
        let ble = self.bleService
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            // Layer 1 + 2: IOKit + HID Generic (동기)
            let ioMap = batteryService.fetchBatteryLevels()
            // Layer 3: BLE GATT 0x180F (비동기 completion → continuation 변환)
            let bleMap = await withCheckedContinuation { (cont: CheckedContinuation<[String: Int], Never>) in
                ble.fetchBatteryLevels { map in cont.resume(returning: map) }
            }
            // IOKit 우선, BLE로 보완 (IOKit 결과가 없는 장치만 BLE로 채움)
            let merged = ioMap.merging(bleMap) { iokit, _ in iokit }
            await MainActor.run {
                self.devices = self.buildDeviceList(batteryMap: merged)
            }
        }
    }

    // DISC-01, DISC-02, BATT-04, MGMT-01: build sorted + filtered device list
    private func buildDeviceList(batteryMap: [String: Int]) -> [BluetoothDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        let connected = paired.filter { $0.isConnected() }
        let prefs = DevicePreferences.shared
        let deviceList: [BluetoothDevice] = connected.map { device in
            // Pitfall 3: multi-source name resolution
            let name = device.name ?? "알 수 없는 장치"
            let type = DeviceType.from(classOfDevice: UInt32(device.classOfDevice))
            // Match IOKit battery by name (best-effort — Product key may differ from IOBluetooth name)
            let battery = batteryMap[name]
            let isMonitored = prefs.isMonitored(name)
            return BluetoothDevice(name: name, type: type, batteryPercent: battery,
                                   isConnected: true, isMonitored: isMonitored)
        }
        // 비모니터링 장치는 popover에서 제외 (RESEARCH.md Open Question 3)
        return deviceList.filter { $0.isMonitored }.sorted()
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
