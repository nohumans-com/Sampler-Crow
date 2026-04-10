import SwiftUI

struct ProjectBarView: View {
    let project: Project
    let onSave: () -> Void
    let onLoad: () -> Void
    let onNew: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Dirty indicator
            if project.isDirty {
                Circle()
                    .fill(.orange)
                    .frame(width: 6, height: 6)
            }

            // Project name
            Text(project.name)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            // Buttons
            Button("New") { onNew() }
                .buttonStyle(.bordered)
                .controlSize(.mini)

            Button("Save") { onSave() }
                .buttonStyle(.bordered)
                .controlSize(.mini)

            Button("Load") { onLoad() }
                .buttonStyle(.bordered)
                .controlSize(.mini)

            Button("Export") { onExport() }
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}
