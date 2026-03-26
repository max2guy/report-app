import Foundation
import CoreBluetooth

private let batteryServiceUUID  = CBUUID(string: "180F")
private let batteryLevelUUID    = CBUUID(string: "2A19")

struct BLEResult {
    let name: String
    let batteryLevel: Int
}

class BLEProbe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private(set) var results: [BLEResult] = []
    private(set) var isDone: Bool = false
    private var scanTimer: Timer?
    private var pendingPeripherals: Set<CBPeripheral> = []

    func start() {
        // CBCentralManager init triggers system Bluetooth permission prompt if needed
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("[BLE] Bluetooth powered on — starting scan")

            // Pitfall 4 fix: retrieve already-connected peripherals first
            let connected = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])
            if !connected.isEmpty {
                print("[BLE] Found \(connected.count) already-connected peripheral(s) with Battery Service")
                for p in connected {
                    pendingPeripherals.insert(p)
                    p.delegate = self
                    central.connect(p, options: nil)
                }
            }

            // Also scan for advertising peripherals
            central.scanForPeripherals(withServices: [batteryServiceUUID], options: nil)

            // Stop scan after 10 seconds (Pitfall 3 / Anti-pattern fix)
            scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.central.stopScan()
                print("[BLE] Scan complete (10s timeout)")
                if self.pendingPeripherals.isEmpty {
                    self.isDone = true
                }
            }

        case .unauthorized:
            print("[BLE] Bluetooth permission denied — FEAS-03 cannot be tested")
            print("[BLE] Grant Bluetooth access in System Settings > Privacy & Security > Bluetooth")
            isDone = true
        case .poweredOff:
            print("[BLE] Bluetooth is off — turn on Bluetooth to test FEAS-03")
            isDone = true
        default:
            print("[BLE] Bluetooth state: \(central.state.rawValue) — cannot scan")
            isDone = true
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        print("[BLE] Discovered peripheral: \(name)")
        pendingPeripherals.insert(peripheral)
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([batteryServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[BLE] Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "unknown error")")
        pendingPeripherals.remove(peripheral)
        checkDone()
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            print("[BLE] Service discovery error for \(peripheral.name ?? "Unknown"): \(error.localizedDescription)")
            pendingPeripherals.remove(peripheral)
            checkDone()
            return
        }
        for service in peripheral.services ?? [] where service.uuid == batteryServiceUUID {
            peripheral.discoverCharacteristics([batteryLevelUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            print("[BLE] Characteristic discovery error: \(error.localizedDescription)")
            pendingPeripherals.remove(peripheral)
            checkDone()
            return
        }
        for char in service.characteristics ?? [] where char.uuid == batteryLevelUUID {
            peripheral.readValue(for: char)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer {
            pendingPeripherals.remove(peripheral)
            checkDone()
        }
        guard error == nil,
              let data = characteristic.value,
              let level = data.first else {
            print("[BLE] Could not read battery level from \(peripheral.name ?? "Unknown")")
            return
        }
        let name = peripheral.name ?? "Unknown"
        results.append(BLEResult(name: name, batteryLevel: Int(level)))
        print("[BLE] Peripheral: \(name), BatteryLevel: \(level)% (via GATT 0x180F)")
    }

    private func checkDone() {
        // Mark done when scan timer has fired AND no more pending peripherals
        if !central.isScanning && pendingPeripherals.isEmpty {
            isDone = true
        }
    }
}

func runBLEProbe() {
    let probe = BLEProbe()
    probe.start()

    // Pitfall 2 fix: RunLoop wait for async CBCentral callbacks
    let deadline = Date(timeIntervalSinceNow: 15)
    while Date() < deadline && !probe.isDone {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
    }

    if probe.results.isEmpty {
        print("[BLE] No peripherals found advertising Battery Service 0x180F")
    }
    print("[BLE] FEAS-03 result: \(probe.results.count) peripheral(s) expose Battery Service 0x180F")
}
