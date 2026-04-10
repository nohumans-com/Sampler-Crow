import SwiftUI

struct SDEntry: Identifiable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    let size: Int?
}

@Observable
@MainActor
final class FileBrowserViewModel {
    var currentPath: String = "/"
    var entries: [SDEntry] = []
    var selectedEntry: SDEntry?
    var isLoading = false
    var pathHistory: [String] = ["/"]

    var isPreviewPlaying = false
    var isPreviewLooping = false

    let appState: AppState
    var onSampleSelected: ((Int, String) -> Void)?
    var targetTrack: Int = 0
    var targetPad: Int = 0

    init(appState: AppState) {
        self.appState = appState
    }

    // --- Navigation ---

    func requestDirectory(_ path: String) {
        isLoading = true
        entries = []
        currentPath = path
        Task { try? await appState.serialService.send("DIR:\(path)") }
    }

    func navigateInto(_ entry: SDEntry) {
        guard entry.isDirectory else { return }
        pathHistory.append(currentPath)
        let newPath = currentPath == "/" ? "/\(entry.name)" : "\(currentPath)/\(entry.name)"
        requestDirectory(newPath)
    }

    func navigateBack() {
        guard pathHistory.count > 1 else { return }
        let prev = pathHistory.removeLast()
        requestDirectory(prev)
    }

    func navigateToRoot() {
        pathHistory = ["/"]
        requestDirectory("/")
    }

    func selectEntry(_ entry: SDEntry) {
        selectedEntry = entry
    }

    // --- Sample loading ---

    func loadSelectedSample() {
        guard let entry = selectedEntry, !entry.isDirectory else { return }
        let fullPath = entryFullPath(entry)

        if targetTrack < appState.tracks.count && appState.tracks[targetTrack].isDrumMachine {
            // Load into drum pad
            let pad = targetPad
            Task { try? await appState.serialService.send("LOADPAD:\(targetTrack):\(pad):\(fullPath)") }
            if pad >= 0 && pad < 8 {
                appState.tracks[targetTrack].drumPads[pad].samplePath = fullPath
                appState.tracks[targetTrack].drumPads[pad].sampleName = entry.name
            }
        } else {
            // Load as regular sample
            Task { try? await appState.serialService.send("LOADSAMPLE:\(targetTrack):\(fullPath)") }
            if targetTrack < appState.tracks.count {
                appState.tracks[targetTrack].trackType = .sampler
                appState.tracks[targetTrack].samplerState.samplePath = fullPath
                appState.tracks[targetTrack].samplerState.sampleName = entry.name
            }
        }

        onSampleSelected?(targetTrack, fullPath)
    }

    // --- Preview playback ---

    func previewSelected() {
        guard let entry = selectedEntry, !entry.isDirectory else { return }
        let fullPath = entryFullPath(entry)
        isPreviewPlaying = true
        isPreviewLooping = false
        Task { try? await appState.serialService.send("PREVIEW:\(fullPath)") }
    }

    func previewLoopSelected() {
        guard let entry = selectedEntry, !entry.isDirectory else { return }
        let fullPath = entryFullPath(entry)
        isPreviewPlaying = true
        isPreviewLooping = true
        Task { try? await appState.serialService.send("PREVIEWLOOP:\(fullPath)") }
    }

    func previewStop() {
        isPreviewPlaying = false
        isPreviewLooping = false
        Task { try? await appState.serialService.send("PREVIEWSTOP") }
    }

    /// Spacebar action when Samples tab is active
    func spacebarAction() {
        if isPreviewPlaying {
            previewStop()
        } else {
            previewSelected()
        }
    }

    // --- Helpers ---

    private func entryFullPath(_ entry: SDEntry) -> String {
        currentPath == "/" ? "/\(entry.name)" : "\(currentPath)/\(entry.name)"
    }

    // --- Serial response handlers ---

    func handleDirList(_ path: String) {
        currentPath = path
        entries = []
        isLoading = true
    }

    func handleFileEntry(_ name: String, size: Int) {
        entries.append(SDEntry(name: name, isDirectory: false, size: size))
    }

    func handleDirEntry(_ name: String) {
        entries.append(SDEntry(name: name, isDirectory: true, size: nil))
    }

    func handleEndDir() {
        isLoading = false
        entries.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
