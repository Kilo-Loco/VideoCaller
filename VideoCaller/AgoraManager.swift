//
//  AgoraManager.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import AgoraRtcKit
import AVKit
import Foundation

open class AgoraManager: NSObject, ObservableObject {

    public let appId: String
    public var role: AgoraClientRole = .audience {
        didSet { agoraEngine.setClientRole(role) }
    }

    @Published public var allUsers: Set<UInt> = []
    @Published var label: String?
    @Published public var localUserId: UInt = 0

    // MARK: - Agora Engine Functions

    private var engine: AgoraRtcEngineKit?
    /// The Agora RTC Engine Kit for the session.
    public var agoraEngine: AgoraRtcEngineKit {
        if let engine { return engine }
        let engine = setupEngine()
        self.engine = engine
        return engine
    }

    open func setupEngine() -> AgoraRtcEngineKit {
        let eng = AgoraRtcEngineKit.sharedEngine(withAppId: appId, delegate: self)
        eng.enableVideo()
        eng.setClientRole(role)
        return eng
    }
    
    @discardableResult
    open func joinChannel(
        _ channel: String, token: String? = nil, uid: UInt = 0,
        mediaOptions: AgoraRtcChannelMediaOptions? = nil
    ) async -> Int32 {
        if await !AgoraManager.checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        if let mediaOptions {
            return self.agoraEngine.joinChannel(
                byToken: token, channelId: channel,
                uid: uid, mediaOptions: mediaOptions
            )
        }
        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            info: nil, uid: uid
        )
    }
    
    @discardableResult
    func joinVideoCall(
        _ channel: String, token: String? = nil, uid: UInt = 0
    ) async -> Int32 {
        
        if await !AgoraManager.checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        let opt = AgoraRtcChannelMediaOptions()
        opt.channelProfile = .communication

        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            uid: uid, mediaOptions: opt
        )
    }
    
    @discardableResult
    func joinVoiceCall(
        _ channel: String, token: String? = nil, uid: UInt = 0
    ) async -> Int32 {
        
        if await !AgoraManager.checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        let opt = AgoraRtcChannelMediaOptions()
        opt.channelProfile = .communication

        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            uid: uid, mediaOptions: opt
        )
    }
    
    @discardableResult
    func joinBroadcastStream(
        _ channel: String, token: String? = nil,
        uid: UInt = 0, isBroadcaster: Bool = true
    ) async -> Int32 {
        if isBroadcaster, await !AgoraManager.checkForPermissions() {
            await self.updateLabel(key: "invalid-permissions")
            return -3
        }

        let opt = AgoraRtcChannelMediaOptions()
        opt.channelProfile = .liveBroadcasting
        opt.clientRoleType = isBroadcaster ? .broadcaster : .audience
        opt.audienceLatencyLevel = isBroadcaster ? .ultraLowLatency : .lowLatency

        return self.agoraEngine.joinChannel(
            byToken: token, channelId: channel,
            uid: uid, mediaOptions: opt
        )
    }

    @discardableResult
    internal func joinChannel(
        _ channel: String, uid: UInt? = nil,
        mediaOptions: AgoraRtcChannelMediaOptions? = nil
    ) async -> Int32 {
        let userId: UInt = 0
        var token = EnvironmentVariable.agoraRtcToken.value
        return await self.joinChannel(
            channel, token: token, uid: userId, mediaOptions: mediaOptions
        )
    }

    @discardableResult
    open func leaveChannel(
        leaveChannelBlock: ((AgoraChannelStats) -> Void)? = nil,
        destroyInstance: Bool = true
    ) -> Int32 {
        let leaveErr = self.agoraEngine.leaveChannel(leaveChannelBlock)
        self.agoraEngine.stopPreview()
        defer { if destroyInstance { AgoraRtcEngineKit.destroy() } }
        self.allUsers.removeAll()
        return leaveErr
    }

    public init(appId: String, role: AgoraClientRole = .audience) {
        self.appId = appId
        self.role = role
    }

    @MainActor
    func updateLabel(to message: String) {
        self.label = message
    }

    @MainActor
    func updateLabel(key: String, comment: String = "") {
        self.label = NSLocalizedString(key, comment: comment)
    }
}

extension AgoraManager: AgoraRtcEngineDelegate {
    /// local user has successfully joined the channel
    open func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        self.localUserId = uid
        if self.role == .broadcaster {
            self.allUsers.insert(uid)
        }
    }

    /// remote user has joined the channel
    open func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        self.allUsers.insert(uid)
    }

    /// remote user has left the channel
    open func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        self.allUsers.remove(uid)
    }
}

extension AgoraManager {
    static func checkForPermissions() async -> Bool {
        var hasPermissions = await self.avAuthorization(mediaType: .video)
        if !hasPermissions { return false }
        hasPermissions = await self.avAuthorization(mediaType: .audio)
        return hasPermissions
    }

    static func avAuthorization(mediaType: AVMediaType) async -> Bool {
        let mediaAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch mediaAuthorizationStatus {
        case .denied, .restricted: return false
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: mediaType) { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default: return false
        }
    }
}
