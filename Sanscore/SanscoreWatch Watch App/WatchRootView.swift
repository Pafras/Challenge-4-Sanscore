//  WatchRootView.swift
//  SanscoreWatch Watch App
//
//  The whole watch UI. Three screens, switched by `connector.state`:
//    .waiting   → "Open Sanscore on iPhone"     (phone not linked)
//    .ready     → "Connected"                    (idle, waiting for your turn)
//    .measuring → animated heart + live BPM      (you're answering) ⭐
//
//  RULE (same as the iOS side): this file imports ONLY SwiftUI, reads
//  `connector.state` + `connector.bpm`, and computes NOTHING. All the HealthKit /
//  WatchConnectivity logic lives in WatchConnector.swift.
//
//  OWNER: Marleen — restyle these three screens to match Satria's Figma. The
//  screen set + the two values you read (`state`, `bpm`) are fixed; the looks
//  are yours. This is a working stub, not the final design.

import SwiftUI

struct WatchRootView: View {
    var connector: WatchConnector

    var body: some View {
        screen
        #if DEBUG
        // Temporary: tap anywhere to start/stop a real HR read without the phone.
        .onTapGesture { connector.debugToggleMeasure() }
        #endif
    }

    @ViewBuilder private var screen: some View {
        switch connector.state {
        case .waiting:   WaitingView()
        case .ready:     ReadyView()
        case .measuring: MeasuringView(bpm: connector.bpm)
        }
    }
}

// MARK: - Screen 1: waiting for the phone
private struct WaitingView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.gen3")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Open Sanscore\non iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Screen 2: connected, idle
private struct ReadyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundStyle(.pink)
            Text("Connected")
                .font(.headline)
            Text("You'll feel a tap\nwhen it's your turn")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Screen 3: measuring ⭐
private struct MeasuringView: View {
    let bpm: Int
    @State private var beat = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(.pink)
                .scaleEffect(beat ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                           value: beat)
            Text(bpm > 0 ? "\(bpm)" : "--")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: bpm)
            Text("BPM")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear { beat = true }
    }
}

#Preview("Measuring") {
    MeasuringView(bpm: 82)
}
