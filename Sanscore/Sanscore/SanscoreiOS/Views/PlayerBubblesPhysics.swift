// PlayerBubblesPhysics.swift
// The "box of balls" for the Game Room: player avatars as physics balls that
// fall in from the top, bounce off the walls and each other, and respond to the
// phone's tilt/shake (gyroscope). Collisions flash + tick a light haptic.
//
// OWNER: Marleen. Self-contained VIEW + local physics — does NOT touch
// GameViewModel/GameState. Feed it the player ids + avatars; it renders + sims.
//
// NOTE: tilt (CoreMotion) + haptics only work on a REAL device — Simulator shows
// the balls falling under plain downward gravity, no tilt/haptic. See HANDOFF-UI.md.

import SwiftUI
#if os(iOS)
import UIKit
import CoreMotion

struct PlayerBubblesPhysics: View {
    let players: [String]                 // stable ids (peer names)
    let avatars: [String: Data]
    let me: String
    var onTapMe: () -> Void = {}           // tap your own ball → edit profile

    @State private var engine = BubbleEngine()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                // Sync roster + size and advance the sim one frame → current balls.
                let frame = engine.frame(
                    at: timeline.date.timeIntervalSinceReferenceDate,
                    bounds: geo.size, ids: players,
                    radius: Self.radius(count: players.count, in: geo.size))
                ZStack {
                    ForEach(frame, id: \.id) { b in
                        ball(b)
                            .position(b.pos)
                            .onTapGesture { if b.id == me { onTapMe() } }
                    }
                }
            }
        }
        .onAppear { engine.startMotion() }
        .onDisappear { engine.stopMotion() }
    }

    @ViewBuilder
    private func ball(_ b: BubbleEngine.Ball) -> some View {
        let d = b.radius * 2
        ZStack {
            if let data = avatars[b.id], let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Circle().fill(Self.color(for: b.id))
            }
        }
        .frame(width: d, height: d)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(.white, lineWidth: max(3, b.radius * 0.06)))
        .brightness(b.flash * 0.5)                 // collision flash
        .scaleEffect(1 + b.flash * 0.06)
    }

    // Default ~48pt radius for a handful; shrink as more players join.
    static func radius(count: Int, in size: CGSize) -> CGFloat {
        guard count > 0, size.width > 0 else { return 48 }
        let areaPerBall = (size.width * size.height * 0.10) / CGFloat(count)
        return min(48, max(26, sqrt(areaPerBall / .pi)))
    }

    // Stable colour per player (used when they have no avatar photo).
    static func color(for id: String) -> Color {
        let palette = IdentityPalette.colors
        return palette[abs(id.hashValue) % palette.count]
    }
}

// MARK: - Loading bars ("waiting for host" / finding room)

/// Simple animated voice-bars (placeholder for Agung's finding-room animation).
struct LoadingBars: View {
    var color: Color = .white
    private let bars = 5
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<bars, id: \.self) { i in
                Capsule()
                    .fill(color)
                    .frame(width: 4, height: animate ? 22 : 8)
                    .animation(.easeInOut(duration: 0.5).repeatForever()
                        .delay(Double(i) * 0.12), value: animate)
            }
        }
        .frame(height: 24)
        .onAppear { animate = true }
    }
}

// MARK: - Physics engine (equal-mass circle collisions + tilt gravity)

// Plain class (NOT @Observable): TimelineView re-renders every frame, so we
// mutate freely without triggering SwiftUI update loops.
final class BubbleEngine {
    struct Ball: Identifiable {
        let id: String
        var pos: CGPoint
        var vel: CGVector
        var radius: CGFloat
        var flash: CGFloat = 0        // 0…1, decays; brightness on collision
    }

    var balls: [Ball] = []
    var bounds: CGSize = .zero

    private var lastT: Double?
    private let motion = CMMotionManager()
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastHaptic: Double = 0
    private let restitution: CGFloat = 1.0    // no energy loss on bounce
    private let entrySpeed: CGFloat = 260     // momentum when entering from top
    private let floorSpeed: CGFloat = 110     // livelier idle float (never fully stops)
    private let maxSpeed: CGFloat = 1600      // hard shake can really rip
    private let shakeScale: CGFloat = 12000   // shake power → speed (very responsive)
    private let damping: CGFloat = 0.12       // low = shake energy lingers (feels alive)

    // One frame: sync roster/size, advance the sim, return the balls to draw.
    func frame(at t: Double, bounds: CGSize, ids: [String], radius: CGFloat) -> [Ball] {
        self.bounds = bounds
        sync(ids: ids, radius: radius)
        step(time: t)
        return balls
    }

    // Add newcomers falling from the top; drop leavers; keep radius current.
    func sync(ids: [String], radius: CGFloat) {
        let have = Set(balls.map(\.id))
        for id in ids where !have.contains(id) {
            let x = CGFloat.random(in: radius...(max(radius, bounds.width - radius)))
            // Enter from top, heading downward-ish; then bounces forever.
            let angle = CGFloat.random(in: (.pi * 0.25)...(.pi * 0.75))
            balls.append(Ball(id: id, pos: CGPoint(x: x, y: -radius),
                              vel: CGVector(dx: cos(angle) * entrySpeed, dy: sin(angle) * entrySpeed),
                              radius: radius))
        }
        let keep = Set(ids)
        balls.removeAll { !keep.contains($0.id) }
        for i in balls.indices { balls[i].radius = radius }
    }

    func step(time: Double) {
        guard bounds.width > 0 else { return }
        guard let last = lastT else { lastT = time; return }
        let dt = min(CGFloat(time - last), 1.0 / 30.0)   // clamp big gaps
        lastT = time

        // NO gravity — pure momentum + shake. userAcceleration (shake) adds
        // speed; light damping eases back toward a gentle float; speed is
        // floored (never stops) and capped (hard shake can't fling them away).
        let kick = shakeAccel()
        for i in balls.indices {
            balls[i].vel.dx += kick.dx * dt
            balls[i].vel.dy += kick.dy * dt
            balls[i].vel.dx -= balls[i].vel.dx * damping * dt
            balls[i].vel.dy -= balls[i].vel.dy * damping * dt
            clampSpeed(&balls[i].vel)
            balls[i].pos.x += balls[i].vel.dx * dt
            balls[i].pos.y += balls[i].vel.dy * dt
            if balls[i].flash > 0 { balls[i].flash = max(0, balls[i].flash - dt * 3) }
        }
        resolveWalls()
        resolvePairs()
    }

    // Shake force from userAcceleration (excludes gravity → no down-pull).
    // Stronger shake = bigger kick = faster balls.
    private func shakeAccel() -> CGVector {
        guard let u = motion.deviceMotion?.userAcceleration else { return .zero }
        return CGVector(dx: CGFloat(u.x) * shakeScale, dy: CGFloat(-u.y) * shakeScale)
    }

    // Keep speed between a gentle floor (always floating) and a hard cap.
    private func clampSpeed(_ v: inout CGVector) {
        let s = hypot(v.dx, v.dy)
        guard s > 0.1 else { v = CGVector(dx: floorSpeed, dy: 0); return }
        let target = min(max(s, floorSpeed), maxSpeed)
        let k = target / s
        v.dx *= k; v.dy *= k
    }

    // Reflect off all 4 edges; abs()-flip keeps speed constant (no energy loss).
    // Top only reflects when moving UP, so balls can still enter from above.
    private func resolveWalls() {
        for i in balls.indices {
            let r = balls[i].radius
            if balls[i].pos.x < r { balls[i].pos.x = r; balls[i].vel.dx = abs(balls[i].vel.dx); balls[i].flash = 0.6 }
            else if balls[i].pos.x > bounds.width - r { balls[i].pos.x = bounds.width - r; balls[i].vel.dx = -abs(balls[i].vel.dx); balls[i].flash = 0.6 }
            if balls[i].pos.y > bounds.height - r { balls[i].pos.y = bounds.height - r; balls[i].vel.dy = -abs(balls[i].vel.dy); balls[i].flash = 0.6 }
            else if balls[i].pos.y < r && balls[i].vel.dy < 0 { balls[i].pos.y = r; balls[i].vel.dy = abs(balls[i].vel.dy); balls[i].flash = 0.6 }
        }
    }

    private func resolvePairs() {
        guard balls.count > 1 else { return }
        for a in 0..<(balls.count - 1) {
            for b in (a + 1)..<balls.count {
                let dx = balls[b].pos.x - balls[a].pos.x
                let dy = balls[b].pos.y - balls[a].pos.y
                let dist = max(0.0001, hypot(dx, dy))
                let minDist = balls[a].radius + balls[b].radius
                guard dist < minDist else { continue }
                let nx = dx / dist, ny = dy / dist
                let overlap = (minDist - dist) / 2
                balls[a].pos.x -= nx * overlap; balls[a].pos.y -= ny * overlap
                balls[b].pos.x += nx * overlap; balls[b].pos.y += ny * overlap
                let rvx = balls[b].vel.dx - balls[a].vel.dx
                let rvy = balls[b].vel.dy - balls[a].vel.dy
                let vn = rvx * nx + rvy * ny
                if vn < 0 {
                    let imp = -(1 + restitution) * vn / 2   // equal mass
                    balls[a].vel.dx -= imp * nx; balls[a].vel.dy -= imp * ny
                    balls[b].vel.dx += imp * nx; balls[b].vel.dy += imp * ny
                    balls[a].flash = 1; balls[b].flash = 1
                    tick(strength: min(1, -vn / 800))
                }
            }
        }
    }

    // MARK: motion + haptics
    func startMotion() {
        haptic.prepare()
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates()
    }
    func stopMotion() { motion.stopDeviceMotionUpdates() }

    private func tick(strength: CGFloat) {
        guard let t = lastT, t - lastHaptic > 0.05 else { return }   // throttle
        lastHaptic = t
        haptic.impactOccurred(intensity: max(0.2, strength))
    }
}
#endif
