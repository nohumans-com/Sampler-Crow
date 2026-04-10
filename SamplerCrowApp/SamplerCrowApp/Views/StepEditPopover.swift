import SwiftUI

struct StepEditPopover: View {
    @Bindable var viewModel: GridViewModel

    private static let trackNames = ["Kick", "Snare", "ClHat", "OpHat", "Clap", "Bass", "Lead", "Pluck"]

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    @State private var velocityDebounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: track name + step number
            HStack {
                if let sel = viewModel.selectedStep {
                    Text("\(Self.trackNames[sel.track]) - Step \(sel.step + 1)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                }
                Spacer()
                Button {
                    viewModel.selectedStep = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Note picker
            HStack {
                Text("Note:")
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 60, alignment: .leading)

                Button {
                    if viewModel.stepNote > 0 {
                        viewModel.setStepNote(viewModel.stepNote - 1)
                    }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)

                Text(Self.noteName(for: viewModel.stepNote))
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 44, alignment: .center)

                Button {
                    if viewModel.stepNote < 127 {
                        viewModel.setStepNote(viewModel.stepNote + 1)
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            // Velocity slider
            HStack {
                Text("Vel:")
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 60, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.stepVelocity) },
                        set: { newValue in
                            let intVal = Int(newValue)
                            viewModel.stepVelocity = intVal
                            // Debounce: only send after 100ms of no changes
                            velocityDebounceTask?.cancel()
                            velocityDebounceTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                viewModel.setStepVelocity(intVal)
                            }
                        }
                    ),
                    in: 1...127,
                    step: 1
                )

                Text("\(viewModel.stepVelocity)")
                    .font(AppTheme.monoFont)
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    /// Convert MIDI note number to readable name like "C4", "D#2"
    static func noteName(for midiNote: Int) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}
