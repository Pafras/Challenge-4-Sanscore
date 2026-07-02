// SanscoreApp.swift
// App entry point. For now it shows the DevTestView so the whole logic
// pipeline can be run on-device / in the Simulator while the real screens are
// being built. Swap DevTestView() for the real first screen when it exists.
//
// OWNER: Pafras (iOS).

import SwiftUI

@main
struct SanscoreApp: App {
    var body: some Scene {
        WindowGroup {
            GameFlowView()
        }
    }
}
