//
//  RoleSpectatorView.swift
//  Sanscore
//
//  Created by Agung Ananda on 06/07/26.
//

import SwiftUI

struct RoleSpectatorView: View {
    
    // ─── TUNABLES ─────────────────────────────────────────────────────────
    private let stickerName = "youre-the-spectator-new"   // the role sticker
    private let bgName = "role-spectator-bg-white"        // grouped black+white bg
    private let stickerWidth: CGFloat = 400             // final size
    private let startScale: CGFloat = 0.002               // size when it first appears
    private let stickerOffsetY: CGFloat = 30             // 0 = screen middle
    // ──────────────────────────────────────────────────────────────────────
    
    @State private var appeared = false
   
    var body: some View {
        ZStack {
            Image(bgName)
                .resizable()
                .ignoresSafeArea()

            // Sticker grows from `startScale` -> 1, centered (scaleEffect scales
            // about the center, so it "opens up" from the middle of the screen).
            Image(stickerName)
                .resizable()
                .scaledToFit()
                .frame(width: stickerWidth)
                .offset(y: stickerOffsetY)
                .scaleEffect(appeared ? 1 : startScale)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.4)) {
                appeared = true
            }
        }
    }
}

#Preview {
    RoleSpectatorView()
}

