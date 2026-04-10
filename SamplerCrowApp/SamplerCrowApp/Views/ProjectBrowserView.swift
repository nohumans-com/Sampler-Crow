import SwiftUI

struct ProjectBrowserView: View {
    @Bindable var projectVM: ProjectViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PROJECTS")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button("Import from Mac") {
                    projectVM.importFromMac()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(12)

            Divider()

            // Project list
            if projectVM.projectNames.isEmpty {
                VStack(spacing: 8) {
                    Text("No saved projects")
                        .font(AppTheme.monoFont)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Save your current session or import a .json file")
                        .font(AppTheme.monoFontSmall)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(projectVM.projectNames, id: \.self) { name in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(AppTheme.accent)
                            .font(.system(size: 12))

                        Text(name)
                            .font(AppTheme.monoFont)
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Button("Load") {
                            projectVM.loadProject(name: name)
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)

                        Button("Delete") {
                            projectVM.deleteProject(name: name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 450, height: 320)
        .onAppear {
            projectVM.listProjects()
        }
    }
}
