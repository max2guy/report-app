import Foundation

/// UserDefaults 기반 장치 선택 + 폴링 간격 영속 레이어.
/// Sandbox-scoped. 앱 재시작 후에도 설정 유지 (MGMT-02).
final class DevicePreferences {
    static let shared = DevicePreferences()
    private init() {}

    private let monitoredKey  = "com.btbatterymonitor.monitoredDevices"
    private let pollingKey    = "com.btbatterymonitor.pollingInterval"

    // MARK: - 장치 모니터링 선택 (MGMT-01, MGMT-02)

    /// 모니터링 활성화된 장치 이름 Set.
    /// Pitfall 4: 장치 이름을 primary key로 사용 (IOKit+BLE 통합 식별 가능, UUID보다 안정적).
    var monitoredDeviceNames: Set<String> {
        get {
            let arr = UserDefaults.standard.stringArray(forKey: monitoredKey) ?? []
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: monitoredKey)
        }
    }

    /// 최초 설치 시 기본값: 모든 장치 모니터링 활성.
    /// key가 존재하지 않으면 (= 최초 설치) true 반환.
    func isMonitored(_ deviceName: String) -> Bool {
        guard UserDefaults.standard.object(forKey: monitoredKey) != nil else { return true }
        return monitoredDeviceNames.contains(deviceName)
    }

    func setMonitored(_ deviceName: String, _ monitored: Bool) {
        var set = monitoredDeviceNames
        if monitored { set.insert(deviceName) } else { set.remove(deviceName) }
        monitoredDeviceNames = set
    }

    // MARK: - 폴링 간격 (MGMT-03, BATT-03)

    var pollingInterval: PollingInterval {
        get { PollingInterval.from(userDefaults: .standard) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: pollingKey) }
    }
}
