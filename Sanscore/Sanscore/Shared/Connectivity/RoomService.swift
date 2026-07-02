// RoomService.swift
// The room. Face-to-face group play (4-5) over MultipeerConnectivity — local,
// no server, no internet. One phone hosts ("make room"), others join. Only the
// RoundResult (name + score + verdict) travels between phones — never raw heart
// rate or voice.
//
// OWNER: Pafras. iOS (local network).
//
// Info.plist required:
//   NSLocalNetworkUsageDescription
//   NSBonjourServices = ["_sanscore._tcp", "_sanscore._udp"]
//
// Handles connect + all room messages (turn assignment, question, result) over
// one send/receive path (RoomMessage). The host decides turns; every message is
// broadcast the same way.

#if os(iOS)
import Foundation
import MultipeerConnectivity

@Observable
final class RoomService: NSObject {

    static let serviceType = "sanscore"   // must be <=15 chars, lowercase + hyphen

    let myPeerID: MCPeerID
    let session: MCSession

    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // UI watches these.
    var connectedPeers: [String] = []
    var isHost = false

    // Host's 4-digit room code; joiners must enter it to be accepted.
    var roomCode = ""

    // Nearby hosts the joiner can pick from (custom browser, so we can gate
    // joining behind the code).
    var foundRooms: [MCPeerID] = []

    // Called whenever a message arrives from another phone.
    var onMessage: ((RoomMessage) -> Void)?
    // Called whenever the connected-peers set changes (join or leave).
    var onConnectionChange: (() -> Void)?
    // Called with the display name of a peer that just left.
    var onPeerLeft: ((String) -> Void)?

    init(displayName: String) {
        myPeerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                               discoveryInfo: nil,
                                               serviceType: RoomService.serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: RoomService.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    // "Make room" — become host, generate a code, accept matching joiners.
    func startHosting() {
        isHost = true
        roomCode = String(format: "%04d", Int.random(in: 0...9999))
        advertiser.startAdvertisingPeer()
    }
    func stopHosting() { advertiser.stopAdvertisingPeer() }

    // "Join room" — start listening for nearby hosts.
    func startBrowsing() { browser.startBrowsingForPeers() }
    func stopBrowsing() { browser.stopBrowsingForPeers() }

    // Joiner tapped a room + entered a code — invite with the code attached.
    func join(_ host: MCPeerID, code: String) {
        browser.invitePeer(host, to: session, withContext: Data(code.utf8), timeout: 15)
    }

    // Everyone in the room, host first, in a stable order — the host uses this
    // for round-robin turn assignment.
    var players: [String] { ([myPeerID.displayName] + connectedPeers).sorted() }

    // Send a message to everyone else in the room.
    func send(_ message: RoomMessage) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension RoomService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept only if the joiner sent the right room code.
        let sent = context.flatMap { String(data: $0, encoding: .utf8) }
        invitationHandler(sent == roomCode, session)
    }
}

extension RoomService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.foundRooms.contains(peerID) { self.foundRooms.append(peerID) }
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundRooms.removeAll { $0 == peerID }
        }
    }
}

extension RoomService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers.map { $0.displayName }
            self.onConnectionChange?()
            if state == .notConnected {
                self.onPeerLeft?(peerID.displayName)
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(RoomMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            self.onMessage?(message)
        }
    }
    
    // Unused transports — required by the protocol.
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer p: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer p: MCPeerID, with progress: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer p: MCPeerID, at url: URL?, withError e: Error?) {}
}
#endif
