import Foundation
import IOKit
import IOKit.hid

// IOKitResult, probeIOKit(), queryIOKit() — ported verbatim from Phase 1
// Source: bt-battery-probe/Sources/bt-battery-probe/IOKitProbe.swift

struct IOKitResult {
    let product: String
    let batteryPercent: Int?
    let serviceClass: String
}

func probeIOKit() -> [IOKitResult] {
    var results: [IOKitResult] = []

    // Primary: AppleDeviceManagementHIDEventService (covers BT HID devices including keyboards/mice)
    results += queryIOKit(matchingClass: "AppleDeviceManagementHIDEventService")

    // Secondary: IOBluetoothDevice (broader Classic BT device coverage)
    let secondary = queryIOKit(matchingClass: "IOBluetoothDevice")
    // Deduplicate by product name
    let existingProducts = Set(results.map { $0.product })
    results += secondary.filter { !existingProducts.contains($0.product) }

    return results
}

private func queryIOKit(matchingClass: String) -> [IOKitResult] {
    var results: [IOKitResult] = []
    var iterator: io_iterator_t = 0

    let matching = IOServiceMatching(matchingClass)
    let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
    guard kr == KERN_SUCCESS else {
        print("[IOKit] IOServiceGetMatchingServices(\(matchingClass)) failed: \(kr)")
        return results
    }
    defer { IOObjectRelease(iterator) }

    var service: io_object_t = IOIteratorNext(iterator)
    while service != 0 {
        defer {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { continue }

        let product = (dict["Product"] as? String) ?? (dict["kIOHIDProductKey"] as? String) ?? "Unknown"
        let battery = dict["BatteryPercent"] as? Int

        results.append(IOKitResult(product: product, batteryPercent: battery, serviceClass: matchingClass))
    }
    return results
}

// MARK: - HID Generic Battery (Pitfall 7: Keychron K3 등 HID UsagePage=6 장치)

/// IOHIDManager를 사용하여 HID UsagePage=6 Usage=0x20 (Battery Strength) 원소가 있는
/// BT 장치의 배터리 레벨을 읽는다.
/// GetValue는 캐시값 반환 — 0이면 실시간 Input Report 미수신 상태 (유효하지 않은 값).
func probeHIDGenericDevice() -> [String: Int] {
    var results: [String: Int] = [:]

    // IOHIDManagerCreate + kIOHIDOptionsTypeNone (Exclusive access 없이 열기)
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

    // 매칭: UsagePage=6 (Generic Device), Usage=0x20 (Battery Strength)
    let matching: [String: Any] = [
        kIOHIDDeviceUsagePageKey as String: 6,
        kIOHIDDeviceUsageKey as String: 0x20
    ]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

    guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
        return results
    }
    defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

    guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        return results
    }

    for device in deviceSet {
        // Transport=Bluetooth 장치만 처리 (USB HID 장치 제외)
        let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
        guard transport.lowercased().contains("bluetooth") else { continue }

        let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown HID"

        // 원소 매칭: UsagePage=6, Usage=0x20
        let elemMatch: [String: Any] = [
            kIOHIDElementUsagePageKey as String: 6,
            kIOHIDElementUsageKey as String: 0x20
        ]
        guard let elements = IOHIDDeviceCopyMatchingElements(device, elemMatch as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement],
              let element = elements.first else { continue }

        // GetValue: IOKit 레지스트리 캐시값 읽기
        // IOHIDDeviceGetValue requires non-optional Unmanaged<IOHIDValue> pointer
        let dummyValue = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, element, 0, 0)
        var valueStorage: Unmanaged<IOHIDValue> = Unmanaged.passRetained(dummyValue)
        let kr = IOHIDDeviceGetValue(device, element, &valueStorage)
        guard kr == kIOReturnSuccess else { continue }
        let value = valueStorage.takeUnretainedValue()

        let intValue = IOHIDValueGetIntegerValue(value)
        // 0은 초기 캐시 미수신 상태 (유효하지 않은 값) — 무시
        guard intValue > 0 else { continue }

        results[product] = Int(intValue)
    }

    return results
}

struct BatteryService {
    /// Returns product-name → battery-percent mapping for all IOKit-visible BT devices.
    /// Merges IOKit (AppleDeviceManagementHIDEventService + IOBluetoothDevice) and
    /// HID Generic UsagePage=6 Usage=0x20 results. IOKit takes priority on name collision.
    /// Runs synchronously. Caller must dispatch to background queue (Pitfall 5).
    func fetchBatteryLevels() -> [String: Int] {
        // Layer 1: IOKit AppleDeviceManagementHIDEventService + IOBluetoothDevice
        let ioResults = probeIOKit()
        var map: [String: Int] = [:]
        for r in ioResults {
            if let pct = r.batteryPercent { map[r.product] = pct }
        }

        // Layer 2 (BATT-02 / Pitfall 7): HID Generic UsagePage=6 Usage=0x20
        // IOKit 결과가 없는 장치에 대해 HID 결과로 채움 (IOKit 우선)
        let hidMap = probeHIDGenericDevice()
        for (product, pct) in hidMap {
            if map[product] == nil { map[product] = pct }
        }

        return map
    }
}
