import Foundation

enum PollingInterval: Int, CaseIterable, Identifiable {
    case oneMin    = 60
    case twoMin    = 120
    case fiveMin   = 300
    case tenMin    = 600
    case thirtyMin = 1800

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneMin:    return "1분"
        case .twoMin:    return "2분"
        case .fiveMin:   return "5분"
        case .tenMin:    return "10분"
        case .thirtyMin: return "30분"
        }
    }

    static var `default`: PollingInterval { .fiveMin }

    static func from(userDefaults: UserDefaults = .standard) -> PollingInterval {
        let raw = userDefaults.integer(forKey: "com.btbatterymonitor.pollingInterval")
        return PollingInterval(rawValue: raw) ?? .default
    }
}
