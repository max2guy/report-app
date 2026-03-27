import SwiftUI

/// 설정 창 SwiftUI 뷰.
/// - 폴링 간격 Picker (MGMT-03)
/// EnvironmentObject 대신 직접 초기화 — NSHostingController에서 EnvironmentObject 주입이 복잡하므로 직접 전달.
struct SettingsView: View {
    let bluetoothService: BluetoothService
    @State private var selectedInterval: PollingInterval = DevicePreferences.shared.pollingInterval

    var body: some View {
        Form {
            Section {
                Picker("배터리 갱신 주기", selection: $selectedInterval) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                // macOS 13 compatible: single-param onChange closure
                .onChange(of: selectedInterval) { newValue in
                    // MGMT-03: 폴링 간격 변경 → BluetoothService 즉시 재스케줄링
                    bluetoothService.updatePollingInterval(newValue)
                }
            } header: {
                Text("모니터링 설정")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 280, minHeight: 160)
    }
}
