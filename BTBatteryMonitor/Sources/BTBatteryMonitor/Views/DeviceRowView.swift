import SwiftUI

struct DeviceRowView: View {
    let device: BluetoothDevice
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Type icon (16pt) — 4pt gap before name
            Image(systemName: device.type.symbolName)
                .frame(width: 16, height: 16)
                .foregroundColor(device.batteryPercent == nil
                    ? Color(NSColor.tertiaryLabelColor)
                    : .primary)

            Spacer().frame(width: 8)  // sm gap icon-to-name

            // Device name — truncated
            Text(device.name)
                .font(.body)   // 13pt regular
                .lineLimit(1)
                .foregroundColor(device.batteryPercent == nil
                    ? Color(NSColor.tertiaryLabelColor)
                    : .primary)

            Spacer()

            // Battery area — normal vs no-battery
            if let pct = device.batteryPercent {
                // Progress bar (80pt x 6pt capsule)
                ProgressView(value: Double(pct), total: 100)
                    .progressViewStyle(.linear)
                    .frame(width: 80, height: 6)
                    .tint(batteryColor(pct))
                    .clipShape(Capsule())
                    .accessibilityValue("\(pct)퍼센트")

                Spacer().frame(width: 8)  // sm gap

                // Battery percent label (12pt right-aligned)
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(batteryColor(pct))
                    .frame(minWidth: 36, alignment: .trailing)
                    .accessibilityHidden(true)   // already in accessibilityLabel
            } else {
                // BATT-04: no battery data
                Text("배터리 정보 없음")   // exact copy per Copywriting Contract
                    .font(.caption)   // 11pt
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
            }
        }
        .padding(.horizontal, 16)   // md inset
        .frame(minHeight: 44)        // HIG minimum touch target
        .background(isHovered
            ? Color(NSColor.controlBackgroundColor).opacity(0.5)
            : Color.clear)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(device.batteryPercent != nil
            ? "\(device.name), 배터리 \(device.batteryPercent!)%"
            : "\(device.name), 배터리 정보 없음")
    }

    // Battery color thresholds per UI-SPEC + REQUIREMENTS.md UI-02
    private func batteryColor(_ pct: Int) -> Color {
        if pct >= 70 { return .green }
        if pct >= 30 { return .yellow }
        return .red
    }
}
