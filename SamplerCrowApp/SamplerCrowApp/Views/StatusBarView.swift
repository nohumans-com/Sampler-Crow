import SwiftUI

struct StatusBarView: View {
    let status: ConnectionStatus
    let cpu: String
    let mem: String

    var body: some View {
        HStack(spacing: 12) {
            statusDot("MIDI", state: status.midi)
            statusDot("Serial", state: status.serial)
            statusDot("Audio", state: status.audio)

            Spacer()

            Text("CPU: \(cpu)")
                .font(AppTheme.monoFontSmall)
                .foregroundStyle(AppTheme.textSecondary)

            Text("MEM: \(mem)")
                .font(AppTheme.monoFontSmall)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func statusDot(_ label: String, state: ConnectionState) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(state.isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            )
            .foregroundStyle(state.isConnected ? AppTheme.statusConnected : AppTheme.statusDisconnected)
    }
}
