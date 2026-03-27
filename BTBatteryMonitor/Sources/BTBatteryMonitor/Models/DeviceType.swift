import Foundation

/// Bluetooth device type derived from Class of Device (CoD) bitmask.
enum DeviceType {
    case mouse
    case keyboard
    case headset
    case gamepad
    case other

    /// SF Symbol name for this device type.
    var symbolName: String {
        switch self {
        case .mouse:    return "computermouse"
        case .keyboard: return "keyboard"
        case .headset:  return "headphones"
        case .gamepad:  return "gamecontroller"
        case .other:    return "dot.radiowaves.left.and.right"
        }
    }

    /// Maps IOBluetoothDevice classOfDevice CoD bitmask to DeviceType.
    /// majorClass = (cod >> 8) & 0x1F
    /// minorClass = (cod >> 2) & 0x3F
    static func from(classOfDevice cod: UInt32) -> DeviceType {
        let majorClass = (cod >> 8) & 0x1F
        let minorClass = (cod >> 2) & 0x3F
        switch majorClass {
        case 0x04: return .headset
        case 0x05:
            switch minorClass {
            case 0x02: return .keyboard
            case 0x05: return .mouse
            default:   return .other
            }
        case 0x08: return .gamepad
        default:   return .other
        }
    }
}
