// RoleSuspectView.swift
// Role reveal screen — "you're the SUSS-PECT". Standalone for now, will be
// wired into the game flow later.
//
// Animation sequence:
//   1. White card slides in from the right (sword-sheath feel)
//   2. "you're the" slides in from the left
//   3. "SUSS-PECT" stamps onto the screen (drops from above, scale bounce)
//
// OWNER: Agung. LAYOUT ONLY.

import SwiftUI

struct RoleSuspectView: View {
    @State private var showCard = false
    @State private var showYoureThe = false
    @State private var showSuspect = false

    var body: some View {
        ZStack {
            Image("pink-bg")
                .resizable()
                .ignoresSafeArea()

            // White tilted card — slides from right
            Image("role-suspect-bg")
                .resizable()
                .scaledToFit()
                .frame(width: 560)
                .offset(
                    x: showCard ? 0 : 500,
                    y: showCard ? 0 : -250)

            // "you're the" — slides from left
            Image("youre-the")
                .resizable()
                .scaledToFit()
                .frame(width: 440)
                .offset(
                    x: showYoureThe ? 0 : -400,
                    y: -60
                )

            // "SUSS-PECT" + eyes — stamps down from above
            Image("role-suspect")
                .resizable()
                .scaledToFit()
                .frame(width: 390)
                .offset(y: 120)
                .scaleEffect(showSuspect ? 1 : 3)
                .opacity(showSuspect ? 1 : 0)
        }
        .onAppear {
            // Step 1: white card slides in from right
            withAnimation(.easeOut(duration: 0.6)) {
                showCard = true
            }

            // Step 2: "you're the" slides in from left (after card lands)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showYoureThe = true
                }
            }

            // Step 3: "SUSS-PECT" stamps down (after "you're the" settles)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    showSuspect = true
                }
            }
        }
    }
}

#Preview {
    RoleSuspectView()
}
