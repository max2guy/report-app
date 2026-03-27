import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var bluetoothService: BluetoothService

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(deviceCount: bluetoothService.devices.count)

            if bluetoothService.devices.isEmpty {
                // Empty state (Copywriting Contract)
                VStack(spacing: 8) {
                    Image(systemName: "bluetooth")
                        .font(.system(size: 32))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    Text("연결된 장치 없음")
                        .font(.system(size: 13, weight: .semibold))
                    Text("블루투스 장치를 연결하면 여기에 표시됩니다.")
                        .font(.caption)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, 16)
            } else {
                // D-01: scrollable list, D-03: sorted by battery ascending (sort done in BluetoothService)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(bluetoothService.devices) { device in
                            DeviceRowView(device: device)
                            if device.id != bluetoothService.devices.last?.id {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 352)   // 400pt total - 48pt header = 352pt content area
            }
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
