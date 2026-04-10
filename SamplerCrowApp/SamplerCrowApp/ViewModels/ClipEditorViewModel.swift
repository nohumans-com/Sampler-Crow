import SwiftUI

struct StepData {
    var note: Int = 0
    var velocity: Int = 0
    var gate: Int = 0
    var padIndex: Int = -1    // -1 = empty

    var isActive: Bool { padIndex >= 0 && velocity > 0 }
}

@Observable
@MainActor
final class ClipEditorViewModel {
    let appState: AppState
    var trackIndex: Int
    var stepCount: Int = 8
    var steps: [StepData] = Array(repeating: StepData(), count: 64)
    var selectedStep: Int? = nil
    var currentPlayStep: Int = -1

    private var velTimer: Task<Void, Never>?

    init(appState: AppState, trackIndex: Int) {
        self.appState = appState
        self.trackIndex = trackIndex
    }

    // MARK: - Step Operations

    func toggleStep(_ step: Int, padIndex: Int) {
        guard step >= 0 && step < 64 else { return }
        if steps[step].padIndex == padIndex && steps[step].isActive {
            // Toggle off
            steps[step].padIndex = -1
            steps[step].velocity = 0
            steps[step].gate = 0
            let t = trackIndex
            Task {
                try? await appState.serialService.send("TOGGLE:\(t):\(step):0")
            }
        } else {
            // Toggle on with this pad
            steps[step].padIndex = padIndex
            steps[step].velocity = steps[step].velocity > 0 ? steps[step].velocity : 100
            steps[step].gate = steps[step].gate > 0 ? steps[step].gate : 100
            let t = trackIndex, v = steps[step].velocity
            Task {
                try? await appState.serialService.send("TOGGLE:\(t):\(step):1")
                try? await appState.serialService.send("SETPADIDX:\(t):\(step):\(padIndex)")
                try? await appState.serialService.send("SETVEL:\(t):\(step):\(v)")
            }
        }
    }

    func setStepVelocity(_ step: Int, _ vel: Int) {
        guard step >= 0 && step < 64 else { return }
        let clamped = min(max(vel, 0), 127)
        steps[step].velocity = clamped
        velTimer?.cancel()
        let t = trackIndex, s = step, v = clamped
        velTimer = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            try? await appState.serialService.send("SETVEL:\(t):\(s):\(v)")
        }
    }

    func setStepCount(_ count: Int) {
        stepCount = count
        let t = trackIndex
        Task {
            try? await appState.serialService.send("SETSTEPS:\(t):\(count)")
        }
    }

    func requestClipData() {
        let t = trackIndex
        Task {
            try? await appState.serialService.send("CLIPDATA:\(t)")
        }
    }

    // MARK: - Response Parsing

    /// Parse CLIP response: CLIP:track:n,v,g,p;n,v,g,p;...
    func handleClipResponse(_ data: String) {
        let stepEntries = data.split(separator: ";")
        for (i, entry) in stepEntries.enumerated() {
            guard i < 64 else { break }
            let parts = entry.split(separator: ",").compactMap { Int($0) }
            if parts.count >= 4 {
                steps[i].note = parts[0]
                steps[i].velocity = parts[1]
                steps[i].gate = parts[2]
                steps[i].padIndex = parts[3]
            }
        }
    }
}
