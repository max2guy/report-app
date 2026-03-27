import Foundation
import CoreBluetooth

private let batteryServiceUUID = CBUUID(string: "180F")
private let batteryLevelUUID   = CBUUID(string: "2A19")

/// CoreBluetooth BLE GATT Battery Service(0x180F) 배터리 읽기.
/// fetch는 1회성 읽기 — 완료 후 completion 호출. Thread-safe (CBCentralManager queue에서 실행).
final class BLEService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager?
    private var pendingPeripherals: Set<CBPeripheral> = []
    private var results: [String: Int] = [:]
    private var completion: (([String: Int]) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?

    /// 이미 시스템에 연결된 BLE Battery Service(0x180F) 장치를 조회하고 배터리 레벨을 읽는다.
    /// Pitfall 2: CBCentralManager 초기화는 startMonitoring() 시점까지 지연 (TCC 프롬프트 타이밍).
    func fetchBatteryLevels(completion: @escaping ([String: Int]) -> Void) {
        self.completion = completion
        self.results = [:]
        self.pendingPeripherals = []
        // queue: .global(qos: .userInitiated) — Pitfall 5 방지 (콜백이 메인 큐에서 실행되지 않음)
        central = CBCentralManager(delegate: self, queue: .global(qos: .userInitiated))
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            finish([:])
            return
        }
        let connected = central.retrieveConnectedPeripherals(withServices: [batteryServiceUUID])
        guard !connected.isEmpty else {
            // Pitfall 1: 빈 배열은 에러가 아님 — 해당 장치가 BLE Battery Service 미지원
            finish([:])
            return
        }
        // 5초 per-peripheral 타임아웃 (RESEARCH.md Open Question 1)
        let work = DispatchWorkItem { [weak self] in self?.finish(self?.results ?? [:]) }
        timeoutWorkItem = work
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: work)

        for p in connected {
            pendingPeripherals.insert(p)
            p.delegate = self
            central.connect(p, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([batteryServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        pendingPeripherals.remove(peripheral)
        checkFinish()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { pendingPeripherals.remove(peripheral); checkFinish(); return }
        for svc in peripheral.services ?? [] where svc.uuid == batteryServiceUUID {
            peripheral.discoverCharacteristics([batteryLevelUUID], for: svc)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { pendingPeripherals.remove(peripheral); checkFinish(); return }
        for char in service.characteristics ?? [] where char.uuid == batteryLevelUUID {
            peripheral.readValue(for: char)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        defer { pendingPeripherals.remove(peripheral); checkFinish() }
        guard error == nil, let data = characteristic.value, let level = data.first else { return }
        let name = peripheral.name ?? peripheral.identifier.uuidString
        results[name] = Int(level)
    }

    private func checkFinish() {
        if pendingPeripherals.isEmpty { finish(results) }
    }

    private func finish(_ map: [String: Int]) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        let c = completion
        completion = nil
        c?(map)
    }
}
