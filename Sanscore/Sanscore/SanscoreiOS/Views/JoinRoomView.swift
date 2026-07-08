// JoinRoomView2.swift
// Screen 2b — Room list + code entry. Shows "JOINNN ROOOOM" header + discovered
// nearby rooms as buttons. Tapping a room slides up an inline code-entry card
// (4-digit numpad) instead of a system alert.
//
// OWNER: Agung. Style to Figma. LAYOUT ONLY — call existing vm methods, never
// edit GameViewModel. See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)
import MultipeerConnectivity
import UIKit

struct JoinRoomView: View {
    let vm: GameViewModel
    let dismissAll: () -> Void
    @State private var selected: MCPeerID?
    @State private var showCodeEntry = false
    @State private var digits: [String] = ["", "", "", ""]
    @State private var focusIndex = 0
    @State private var codeCardHeight: CGFloat = 560   // measured -> sheet detent
    @State private var shakes = 0                      // +1 per wrong code -> shake anim
    @State private var showWrongToast = false

    // Pass previewShowCode: true to open straight on the code-entry card —
    // used by #Preview (no nearby rooms there, so no room to tap).
    init(vm: GameViewModel, dismissAll: @escaping () -> Void,
         previewShowCode: Bool = false) {
        self.vm = vm
        self.dismissAll = dismissAll
        _showCodeEntry = State(initialValue: previewShowCode)
    }

    var body: some View {
        ZStack {
            Image("pink-bg")
                .resizable()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("join-room")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 340)
                    .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(vm.room.foundRooms, id: \.self) { host in
                            Button {
                                selected = host
                                resetCode()
                                vm.joinError = nil   // fresh card, no stale warning
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showCodeEntry = true
                                }
                            } label: {
                                RoomRowLabel(text: vm.room.roomNames[host] ?? host.displayName)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }

        }
        // Native sheet = system slide/drag/dim for free; the drawer styling
        // (pink-bg, grabber, corner 40) matches SussConfirmDrawer.
        .sussDrawerDim(showCodeEntry)   // design system: drawers dim darker
        .sheet(isPresented: $showCodeEntry, onDismiss: { selected = nil }) {
            codeEntryCard
        }
        // Close button — SAME construction as IdentityCameraView's corner button
        // (.glassButton + frame 44 + padding 16/8) so every screen's corner
        // button is identical. Overlay (not toolbar) keeps it inside the safe area.
        .overlay(alignment: .topLeading) {
            Button {
                vm.room.stopBrowsing()
                dismissAll()
            } label: {
                StrokedIcon(systemName: "xmark", assetName: "icon-close",
                            size: 16, fill: Color(hex: "E40063"), stroke: .white)
                    .frame(width: 44, height: 44)   // matches identity screen
            }
            .glassButton()
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Code Entry Card

    private var codeEntryCard: some View {
        // Same drawer system as SussConfirmDrawer (pink-bg, custom grabber,
        // corner 40, content-hugging detent) + the ENTER CODE keypad content.
        //
        cardBody
            .frame(maxWidth: .infinity)
            // Content height -> detent, so the sheet hugs the keypad exactly
            // (same trick as SussConfirmDrawer).
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                codeCardHeight = $0
            }
            .presentationDetents([.height(codeCardHeight)])
            .ignoresSafeArea(edges: .bottom)
            .presentationDragIndicator(.hidden)      // custom grabber above
            .presentationCornerRadius(40)
            .presentationBackground {
                // Solid pink UNDER the image: scaledToFill can undershoot the
                // sheet's rounded corners by a hair, letting the black dim layer
                // ring through — the base colour hides that seam.
                ZStack(alignment: .top) {
                    Color(hex: "F27CD8")
                    Image("pink-bg")                 // same bg as the homepage
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
                // The keypad content stops above the home indicator, so the
                // pink bg showed as a strip under the lavender panel. Paint
                // that bottom zone lavender to read as one continuous panel.
                .overlay(alignment: .bottom) {
                    Color(hex: "DEC7F2").frame(height: 60)
                }
            }
            // "Wrong Code!" toast pops in briefly over the title area (the sheet
            // clips its bounds, so it can't float above the drawer).
            .overlay(alignment: .top) {
                if showWrongToast {
                    SusToastView(toast: Toast(message: "Wrong Code!", style: .danger),
                                 icon: "exclamationmark.triangle.fill")
                        .padding(.top, 52)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8),
                       value: showWrongToast)
        // A failed code: buzz + shake the boxes + clear digits + toast.
        .onChange(of: vm.joinError) { _, err in
            if err != nil {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.easeInOut(duration: 0.45)) { shakes += 1 }
                resetCode()
                showWrongToast = true
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    showWrongToast = false
                }
            }
        }
    }

    private var cardBody: some View {
        VStack(spacing: 20) {
            // Grabber: 64 wide, white 50% fill, white 70% OUTSIDE stroke 4.
            Capsule().fill(.white.opacity(0.5))
                .overlay(Capsule().inset(by: -2)
                    .stroke(.white.opacity(0.7), lineWidth: 4))
                .frame(width: 64, height: 10)
                .padding(.top, 18)

            // Large Title 31, design-system stroked text (same combo as
            // SussConfirmDrawer) instead of the fixed-size image asset.
            IdentityTitle(text: "ENTER CODE", size: 31, strokeWidth: 5,
                          fill: Color(hex: "2A1AE8"), stroke: Color(hex: "8FE0FF"),
                          tilt: 0)
                .padding(.top, 6)

            // 4 tall digit boxes. Figma: all boxes fill B3008B 30%; stroke
            // white 5px — 80% focused, 50% filled & idle.
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(hex: "B3008B").opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(
                                        .white.opacity(i == focusIndex ? 0.8 : 0.5),
                                        lineWidth: 5
                                    )
                            )

                        if digits[i].isEmpty && i == focusIndex {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white)
                                .frame(width: 3, height: 64)
                        } else {
                            Text(digits[i])
                                .font(.system(size: 56, weight: .heavy))
                                .fontWidth(.expanded)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 118)
                }
            }
            .padding(.horizontal, 20)
            // Wrong code -> quick side-to-side shake of the whole box row.
            .modifier(ShakeEffect(animatableData: CGFloat(shakes)))

            numpadView
        }
    }

    // MARK: - Shake

    /// Horizontal shake: animatableData +1 = one full shake cycle set.
    private struct ShakeEffect: GeometryEffect {
        var travel: CGFloat = 7    // px left/right
        var cycles: CGFloat = 3    // wiggles per trigger
        var animatableData: CGFloat

        func effectValue(size: CGSize) -> ProjectionTransform {
            ProjectionTransform(CGAffineTransform(
                translationX: travel * sin(animatableData * .pi * 2 * cycles), y: 0))
        }
    }

    // MARK: - Numpad

    private var numpadView: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["", "0", "⌫"]
        ]
        // Light lavender panel with its own rounded top corners, keys = white
        // rounded rects with dark digits (Figma numpad).
        return VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(height: 56)
                        } else {
                            Button {
                                handleKey(key)
                            } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(systemName: "delete.backward")
                                            .font(.title2.weight(.semibold))
                                    } else {
                                        Text(key)
                                            .font(.system(size: 28, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(.black.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    .white.opacity(0.9),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .background {
            // ignoresSafeArea on the GRADIENT (not the keys) stretches the
            // lavender panel to the physical bottom edge — no pink strip under
            // the keypad, like the native iOS keyboard.
            LinearGradient(colors: [Color(hex: "F3E8FA"), Color(hex: "DEC7F2")],
                           startPoint: .top, endPoint: .bottom)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 36,
                                                  topTrailingRadius: 36))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Input Logic

    private func handleKey(_ key: String) {
        vm.joinError = nil   // clear any previous warning as they retype
        if key == "⌫" {
            if focusIndex > 0 && digits[focusIndex].isEmpty {
                focusIndex -= 1
            }
            digits[focusIndex] = ""
        } else {
            digits[focusIndex] = key
            if focusIndex < 3 {
                focusIndex += 1
            } else {
                let fullCode = digits.joined()
                if fullCode.count == 4 {
                    if let host = selected {
                        // Invite but STAY on the card. Correct code -> we connect
                        // and the view switches to the identity screen. Wrong code
                        // -> vm.joinError fills in and the digits reset for a retry
                        // (see .onChange in codeEntryCard). Don't close the card.
                        vm.join(host, code: fullCode)
                    } else {
                        // No room selected = #Preview (real flow always has one).
                        // Fake a wrong code so the shake + toast can be tested.
                        vm.joinError = "Wrong code"
                    }
                }
            }
        }
    }

    private func resetCode() {
        digits = ["", "", "", ""]
        focusIndex = 0
    }
}

// MARK: - Room list row (Figma style)

/// One room button: the room-name-placeholder art as the pill, with the room
/// name (pink, white outline) overlaid. Fully dynamic — every discovered room
/// renders its own placeholder with its name on top.
private struct RoomRowLabel: View {
    let text: String

    // ─── TUNABLES ─────────────────────────────────────────────────────────
    var fontSize: CGFloat = 22
    // ──────────────────────────────────────────────────────────────────────

    var body: some View {
        Image("room-name-placeholder")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)          // pill spans the row width
            .overlay(
                OutlinedText(text: text, size: fontSize)
            )
    }
}

/// Text drawn with a coloured fill and a solid outline (SwiftUI can't stroke a
/// Text directly, so we stack offset copies of the outline colour behind it).
private struct OutlinedText: View {
    let text: String
    var size: CGFloat
    var fill: Color = Color(red: 0.86, green: 0.14, blue: 0.44)   // pink
    var outline: Color = .white
    var outlineWidth: CGFloat = 2

    var body: some View {
        let font = Font.system(size: size, weight: .heavy, design: .rounded)
        ZStack {
            ForEach(Array(offsets.enumerated()), id: \.offset) { _, o in
                Text(text).font(font).foregroundStyle(outline)
                    .offset(x: o.width, y: o.height)
            }
            Text(text).font(font).foregroundStyle(fill)
        }
    }

    private var offsets: [CGSize] {
        let w = outlineWidth
        return [CGSize(width: -w, height: 0), CGSize(width: w, height: 0),
                CGSize(width: 0, height: -w), CGSize(width: 0, height: w),
                CGSize(width: -w, height: -w), CGSize(width: w, height: -w),
                CGSize(width: -w, height: w), CGSize(width: w, height: w)]
    }
}

#Preview("Empty (no rooms found)") {
    NavigationStack {
        JoinRoomView(vm: GameViewModel(), dismissAll: {})
    }
}

// Rooms-available preview: inject a few fake nearby rooms so the list renders
// with no real peers around. foundRooms/roomNames are plain vars on RoomService,
// so we can seed them here. Tweak RoomRowLabel and see it live on these.
#Preview("Rooms available") {
    let vm = GameViewModel()
    let hosts = [
        (MCPeerID(displayName: "host-alpha"),   "Room Alpha"),
        (MCPeerID(displayName: "host-beta"),    "Room Beta"),
        (MCPeerID(displayName: "host-charlie"), "Room Charlie")
    ]
    vm.room.foundRooms = hosts.map(\.0)
    vm.room.roomNames = Dictionary(uniqueKeysWithValues: hosts.map { ($0.0, $0.1) })
    return NavigationStack {
        JoinRoomView(vm: vm, dismissAll: {})
    }
}
#endif
