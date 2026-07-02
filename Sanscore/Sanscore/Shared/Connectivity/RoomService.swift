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
// ponytail: this handles connect + broadcast results. The turn-order state
// machine (whose turn, round number, scoreboard) is NOT here yet — the host
// decides turns and broadcasts them the same way results are broadcast. Add
// that once single-phone play works and you actually wire multiplayer.

#if os(iOS)
import Foundation
import MultipeerConnectivity

@Observable
final class RoomService: NSObject {

    static let serviceType = "sanscore"   // must be <=15 chars, lowercase + hyphen

    let myPeerID: MCPeerID
    let session: MCSession

    private let advertiser: MCNearbyServiceAdvertiser

    // UI watches these.
    var connectedPeers: [String] = []
    var lastReceived: RoundResult?

    // Called whenever a result arrives from another phone.
    var onReceive: ((RoundResult) -> Void)?

    init(displayName: String) {
        myPeerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                               discoveryInfo: nil,
                                               serviceType: RoomService.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
    }

    // "Make room" — become host, accept joiners.
    func startHosting() { advertiser.startAdvertisingPeer() }
    func stopHosting() { advertiser.stopAdvertisingPeer() }

    // Broadcast this round's result to everyone in the room.
    func broadcast(_ result: RoundResult) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(result) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension RoomService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Party game, same room -> auto-accept joiners.
        invitationHandler(true, session)
    }
}

extension RoomService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers.map { $0.displayName }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let result = try? JSONDecoder().decode(RoundResult.self, from: data) else { return }
        DispatchQueue.main.async {
            self.lastReceived = result
            self.onReceive?(result)
        }
    }

    // Unused transports — required by the protocol.
    func session(_ s: MCSession, didReceive stream: InputStream, withName n: String, fromPeer p: MCPeerID) {}
    func session(_ s: MCSession, didStartReceivingResourceWithName n: String, fromPeer p: MCPeerID, with progress: Progress) {}
    func session(_ s: MCSession, didFinishReceivingResourceWithName n: String, fromPeer p: MCPeerID, at url: URL?, withError e: Error?) {}
}
#endif
