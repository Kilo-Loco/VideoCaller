//
//  CustomAudioVideoManager.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import AVKit
import AgoraRtcKit

class CustomAudioVideoManager: AgoraManager, AgoraCameraSourcePushDelegate {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoCaptureDevice: AVCaptureDevice
    var audioCaptureDevice: AVCaptureDevice

    public var cameraPushSource: AgoraCameraSourcePush?
    public var micPushSource: AgoraAudioSourcePush?

    func myVideoCapture(_ pixelBuffer: CVPixelBuffer, rotation: Int, timeStamp: CMTime) {
        let videoFrame = AgoraVideoFrame()
        videoFrame.format = 12
        videoFrame.textureBuf = pixelBuffer
        videoFrame.time = timeStamp
        videoFrame.rotation = Int32(rotation)

        let framePushed = self.agoraEngine.pushExternalVideoFrame(videoFrame)
        if !framePushed {
            print("Frame could not be pushed.")
        }
    }

    init(
        appId: String, role: AgoraClientRole = .audience,
        videoCaptureDevice: AVCaptureDevice, audioCaptureDevice: AVCaptureDevice
    ) {
        self.videoCaptureDevice = videoCaptureDevice
        self.audioCaptureDevice = audioCaptureDevice
        super.init(appId: appId, role: role)

        self.agoraEngine.setExternalVideoSource(true, useTexture: true, sourceType: .videoFrame)
        self.cameraPushSource = AgoraCameraSourcePush(
            videoDevice: videoCaptureDevice,
            onVideoFrameCaptured: self.myVideoCapture(_:rotation:timeStamp:)
        )
        self.previewLayer = self.cameraPushSource?.previewLayer
        self.agoraEngine.createCustomAudioTrack(AgoraAudioTrackType.direct, config: AgoraAudioTrackConfig.init())

        self.micPushSource = AgoraAudioSourcePush(
            audioDevice: audioCaptureDevice,
            onAudioFrameCaptured: self.audioFrameCaptured(buf:)
        )
    }

    func audioFrameCaptured(buf: CMSampleBuffer) {
        agoraEngine.pushExternalAudioFrameSampleBuffer(buf)
    }
    
    @discardableResult
    override func joinChannel(
        _ channel: String, token: String? = nil, uid: UInt = 0,
        mediaOptions: AgoraRtcChannelMediaOptions? = nil
    ) async -> Int32 {
        defer {
            cameraPushSource?.startCapturing()
            micPushSource?.startCapturing()
        }
        let opt = AgoraRtcChannelMediaOptions()
        opt.publishMicrophoneTrack = true
        opt.publishCustomAudioTrack = false
        
        return await super.joinChannel(channel, token: token, uid: uid, mediaOptions: opt)
    }

    @discardableResult
    override func leaveChannel(
        leaveChannelBlock: ((AgoraChannelStats) -> Void)? = nil,
        destroyInstance: Bool = true
    ) -> Int32 {
        // Need to stop the capture on exit
        cameraPushSource?.stopCapturing()
        cameraPushSource = nil
        micPushSource?.stopCapturing()
        micPushSource = nil
        return super.leaveChannel(leaveChannelBlock: leaveChannelBlock, destroyInstance: destroyInstance)
    }

    override func rtcEngine(
        _ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int
    ) {
        self.localUserId = uid
    }
}
