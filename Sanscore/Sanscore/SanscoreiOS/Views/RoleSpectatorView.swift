//
//  RoleSpectatorView.swift
//  Sanscore
//
//  Created by Agung Ananda on 06/07/26.
//

import SwiftUI

struct RoleSpectatorView: View {
    @State private var showCard = false
    @State private var showYoureThe = false
    @State private var showSuspect = false

    var body: some View {
        ZStack {
            Image("black-bg")
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
            Image("role-spectator")
                .resizable()
                .scaledToFit()
                .frame(width: 400)
                .offset(y: 105)
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
    RoleSpectatorView()
}

