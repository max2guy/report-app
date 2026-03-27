import Foundation
import IOKit

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

struct BatteryService {
    /// Returns product-name → battery-percent mapping for all IOKit-visible BT devices.
    /// Runs synchronously. Caller must dispatch to background queue (Pitfall 5).
    func fetchBatteryLevels() -> [String: Int] {
        let results = probeIOKit()
        var map: [String: Int] = [:]
        for r in results {
            if let pct = r.batteryPercent {
                map[r.product] = pct
            }
        }
        return map
    }
}
