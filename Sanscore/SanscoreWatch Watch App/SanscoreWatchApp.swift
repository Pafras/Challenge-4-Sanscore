//
//  SanscoreWatchApp.swift
//  SanscoreWatch Watch App
//
//  Created by Pafras Vio Prayogo on 16/07/26.
//

import SwiftUI
import HealthKit

// The delegate owns the connector so BOTH the workout-launch handoff and the
// view use the same instance. When the iPhone calls startWatchApp(with:), the
// system launches this app and calls handle(_:) — that's our cue to start
// measuring without the user opening the app.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let connector = WatchConnector()

    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        connector.startMeasuring(with: workoutConfiguration)
    }
}

@main
struct SanscoreWatch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            WatchRootView(connector: delegate.connector)
        }
    }
}
