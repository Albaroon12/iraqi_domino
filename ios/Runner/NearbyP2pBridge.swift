import Flutter
import Foundation
import MultipeerConnectivity

/// First-party iOS peer-to-peer transport bridge using Apple's low-latency
/// `MultipeerConnectivity` framework (Bluetooth + Peer-to-Peer Wi-Fi).
final class NearbyP2pBridge: NSObject,
  FlutterStreamHandler,
  MCSessionDelegate,
  MCNearbyServiceAdvertiserDelegate,
  MCNearbyServiceBrowserDelegate
{
  private static let methodChannelName = "com.albaron.iraqi_domino/nearby_p2p"
  private static let eventChannelName = "com.albaron.iraqi_domino/nearby_p2p_events"
  private static let serviceType = "iraqidomino-p2p"

  private var eventSink: FlutterEventSink?
  private var localPeerId: MCPeerID?
  private var session: MCSession?
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?
  private var discoveredPeers: [String: MCPeerID] = [:]
  private var isHostRole: Bool = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NearbyP2pBridge()
    let method = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    let events = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )
    method.setMethodCallHandler(instance.handle)
    events.setStreamHandler(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  private func emit(_ payload: [String: Any?]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "requestPermissions":
      result(true)
    case "ensureWifiDirectGroup", "discoverWifiDirectPeers", "removeWifiDirectGroup",
         "updateBluetoothAdvertisement":
      result([String: Any]())
    case "startBluetoothHost":
      stopAll()
      isHostRole = true
      let hostName = (args["hostName"] as? String) ?? UIDevice.current.name
      let pid = MCPeerID(displayName: String(hostName.prefix(32)))
      localPeerId = pid
      let s = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
      s.delegate = self
      session = s
      let adv = MCNearbyServiceAdvertiser(
        peer: pid,
        discoveryInfo: [
          "playerCount": "\(args["playerCount"] ?? 4)",
          "targetScore": "\(args["targetScore"] ?? 151)"
        ],
        serviceType: Self.serviceType
      )
      adv.delegate = self
      adv.startAdvertisingPeer()
      advertiser = adv
      result(["roomCode": pid.displayName, "deviceName": pid.displayName])

    case "sendToPeer":
      guard let s = session,
            let peerName = args["peerId"] as? String,
            let text = args["payload"] as? String,
            let data = text.data(using: .utf8),
            let target = s.connectedPeers.first(where: { $0.displayName == peerName })
      else {
        result([String: Any]())
        return
      }
      try? s.send(data, toPeers: [target], with: .reliable)
      result([String: Any]())

    case "broadcast":
      if let s = session, !s.connectedPeers.isEmpty,
         let text = args["payload"] as? String,
         let data = text.data(using: .utf8) {
        try? s.send(data, toPeers: s.connectedPeers, with: .reliable)
      }
      result([String: Any]())

    case "stopBluetoothHost":
      stopAll()
      result([String: Any]())

    case "startBluetoothDiscovery":
      stopAll()
      isHostRole = false
      let pid = MCPeerID(displayName: "Client-\(Int.random(in: 1000...9999))")
      localPeerId = pid
      let s = MCSession(peer: pid, securityIdentity: nil, encryptionPreference: .none)
      s.delegate = self
      session = s
      let br = MCNearbyServiceBrowser(peer: pid, serviceType: Self.serviceType)
      br.delegate = self
      br.startBrowsingForPeers()
      browser = br
      result([String: Any]())

    case "stopBluetoothDiscovery":
      browser?.stopBrowsingForPeers()
      browser = nil
      result([String: Any]())

    case "connectBluetoothHost":
      guard let endpoint = args["endpoint"] as? String,
            let target = discoveredPeers[endpoint],
            let br = browser,
            let s = session
      else {
        result(FlutterError(code: "BT_NO_PEER", message: "لم يتم العثور على الجهاز", details: nil))
        return
      }
      br.invitePeer(target, to: s, withContext: nil, timeout: 8)
      result([String: Any]())

    case "clientSend":
      if let s = session, !s.connectedPeers.isEmpty,
         let text = args["payload"] as? String,
         let data = text.data(using: .utf8) {
        try? s.send(data, toPeers: s.connectedPeers, with: .reliable)
      }
      result([String: Any]())

    case "disconnectBluetoothClient":
      stopAll()
      result([String: Any]())

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stopAll() {
    advertiser?.stopAdvertisingPeer()
    advertiser = nil
    browser?.stopBrowsingForPeers()
    browser = nil
    session?.disconnect()
    session = nil
    discoveredPeers.removeAll()
  }

  // MARK: - Advertiser & Browser Delegates

  func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didReceiveInvitationFromPeer peerID: MCPeerID,
    withContext context: Data?,
    invitationHandler: @escaping (Bool, MCSession?) -> Void
  ) {
    invitationHandler(true, session)
  }

  func browser(
    _ browser: MCNearbyServiceBrowser,
    foundPeer peerID: MCPeerID,
    withDiscoveryInfo info: [String: String]?
  ) {
    discoveredPeers[peerID.displayName] = peerID
    let pc = Int(info?["playerCount"] ?? "4") ?? 4
    let ts = Int(info?["targetScore"] ?? "151") ?? 151
    emit([
      "role": "client",
      "type": "deviceFound",
      "endpoint": peerID.displayName,
      "roomCode": peerID.displayName,
      "hostName": peerID.displayName,
      "playerCount": pc,
      "targetScore": ts
    ])
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    discoveredPeers.removeValue(forKey: peerID.displayName)
  }

  // MARK: - MCSessionDelegate

  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    if isHostRole {
      if state == .connected {
        emit(["role": "host", "type": "peerConnected", "peerId": peerID.displayName])
      } else if state == .notConnected {
        emit(["role": "host", "type": "peerDisconnected", "peerId": peerID.displayName])
      }
    } else if state == .notConnected {
      emit(["role": "client", "type": "disconnected"])
    }
  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    guard let text = String(data: data, encoding: .utf8) else { return }
    for line in text.split(separator: "\n") {
      let str = String(line)
      if isHostRole {
        emit(["role": "host", "type": "frame", "peerId": peerID.displayName, "payload": str])
      } else {
        emit(["role": "client", "type": "frame", "payload": str])
      }
    }
  }

  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
