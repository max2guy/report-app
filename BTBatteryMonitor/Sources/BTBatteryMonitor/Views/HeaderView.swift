import SwiftUI

struct HeaderView: View {
    let deviceCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BT Battery Monitor  •  \(deviceCount)개 장치")   // exact copy per Copywriting Contract
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)    // md spacing token
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()
        }
    }
}
