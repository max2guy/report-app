import Foundation

/// Canonical data model representing a paired Bluetooth device.
struct BluetoothDevice: Identifiable {
    let id: UUID
    let name: String
    let type: DeviceType
    let batteryPercent: Int?  // nil = no battery data available (BATT-04)
    let isConnected: Bool
    var isMonitored: Bool    // MGMT-01: 사용자 선택 반영. 기본값 true.

    init(name: String, type: DeviceType, batteryPercent: Int?, isConnected: Bool, isMonitored: Bool = true) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.batteryPercent = batteryPercent
        self.isConnected = isConnected
        self.isMonitored = isMonitored
    }
}

extension BluetoothDevice: Comparable {
    /// Sorts battery ascending (lowest first); nil values sort last (D-03/D-04).
    static func < (lhs: BluetoothDevice, rhs: BluetoothDevice) -> Bool {
        switch (lhs.batteryPercent, rhs.batteryPercent) {
        case let (l?, r?): return l < r
        case (_?, nil):    return true   // has battery sorts before nil
        case (nil, _?):    return false
        case (nil, nil):   return false
        }
    }
}
