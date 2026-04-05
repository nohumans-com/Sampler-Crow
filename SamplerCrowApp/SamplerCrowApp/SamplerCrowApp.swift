import SwiftUI
import Darwin

@main
struct SamplerCrowApp: App {
    init() {
        // Disable stdout buffering so print() output appears immediately
        // when the app is launched from a terminal for debugging.
        setbuf(stdout, nil)
        setbuf(stderr, nil)
        // Also mirror to the unified logging system via NSLog by setting an
        // environment variable consumed by our AudioService logger? Not needed —
        // print() + unbuffered stdout is sufficient when launched from terminal.
        print("SamplerCrowApp: init — stdout unbuffered, launch OK")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 650)
    }
}
