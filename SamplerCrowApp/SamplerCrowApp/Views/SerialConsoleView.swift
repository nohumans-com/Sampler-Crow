import SwiftUI

struct SerialConsoleView: View {
    @Bindable var viewModel: SerialConsoleViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Serial Console")
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button("Connect") {
                    viewModel.connect()
                }
                .buttonStyle(.bordered)

                Button("Disconnect") {
                    viewModel.disconnect()
                }
                .buttonStyle(.bordered)
            }
            .padding(8)

            Divider()

            // Log output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(viewModel.entries) { entry in
                            ConsoleLogRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: viewModel.entries.count) {
                    if let last = viewModel.entries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Command input
            HStack(spacing: 8) {
                TextField("Send command...", text: $viewModel.commandText)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.monoFont)
                    .onSubmit {
                        viewModel.sendCommand()
                    }
                    .onKeyPress(.upArrow) {
                        viewModel.historyUp()
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        viewModel.historyDown()
                        return .handled
                    }

                Button("Send") {
                    viewModel.sendCommand()
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
        }
    }
}

struct ConsoleLogRow: View {
    let entry: LogEntry

    var body: some View {
        Text(entry.text)
            .font(AppTheme.monoFontSmall)
            .foregroundStyle(color)
            .textSelection(.enabled)
    }

    private var color: Color {
        switch entry.type {
        case .incoming: AppTheme.msgIn
        case .outgoing: AppTheme.msgOut
        case .info: AppTheme.msgInfo
        }
    }
}
