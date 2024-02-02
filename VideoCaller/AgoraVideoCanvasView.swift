//
//  AgoraVideoCanvasView.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import SwiftUI
import AVKit
import AgoraRtcKit

struct AgoraCustomVideoCanvasView: UIViewRepresentable {
    
    @StateObject var canvas = CustomVideoSourcePreview()

    var previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> UIView { createCanvasView() }
    func createCanvasView() -> UIView { canvas }

    func updateCanvasValues() {
        if self.previewLayer != canvas.previewLayer, let previewLayer {
            canvas.insertCaptureVideoPreviewLayer(previewLayer: previewLayer)
        }
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        self.updateCanvasValues()
    }
}

class CustomVideoSourcePreview: UIView, ObservableObject {
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    func insertCaptureVideoPreviewLayer(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer?.removeFromSuperlayer()
        previewLayer.frame = bounds
        layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        previewLayer?.frame = bounds
        if let connection = self.previewLayer?.connection {
            let currentDevice = UIDevice.current
            let orientation: UIDeviceOrientation = currentDevice.orientation
            let previewLayerConnection: AVCaptureConnection = connection

            if previewLayerConnection.isVideoOrientationSupported {
                self.updatePreviewLayer(
                    layer: previewLayerConnection,
                    orientation: orientation.toCaptureVideoOrientation()
                )
            }
        }
    }

    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        self.previewLayer?.frame = self.bounds
    }
}

extension AgoraRtcVideoCanvas: ObservableObject {}

protocol CanvasViewHelper: AnyObject {
    var agoraEngine: AgoraRtcEngineKit { get }
    var localUserId: UInt { get }
}

extension AgoraManager: CanvasViewHelper {}

struct AgoraVideoCanvasView: UIViewRepresentable {
    
    @StateObject var canvas = AgoraRtcVideoCanvas()
    weak var manager: CanvasViewHelper?
    var canvasId: CanvasIdType
    enum CanvasIdType: Hashable {
        case userId(UInt)
        case userIdEx(UInt, AgoraRtcConnection)
        
        case mediaSource(AgoraVideoSourceType, mediaPlayerId: Int32?)
    }
    
    func setUserId(to canvasId: CanvasIdType, agoraEngine: AgoraRtcEngineKit) {
        switch canvasId {
        case .userId(let userId):
            canvas.uid = userId
            if userId == manager?.localUserId {
                self.setupLocalVideo(agoraEngine: agoraEngine)
            } else {
                agoraEngine.setupRemoteVideo(canvas)
            }
        case .userIdEx(let userId, let connection):
            canvas.uid = userId
            agoraEngine.setupRemoteVideoEx(canvas, connection: connection)
        case .mediaSource(let sourceType, let playerId):
            canvas.sourceType = sourceType
            if let playerId { canvas.mediaPlayerId = playerId }
            agoraEngine.setupLocalVideo(canvas)
        }
    }

    func setupLocalVideo(agoraEngine: AgoraRtcEngineKit) {
        agoraEngine.startPreview()
        agoraEngine.setupLocalVideo(canvas)
    }
    
    public struct CanvasProperties {
        
        var renderMode: AgoraVideoRenderMode
        var cropArea: CGRect
        var setupMode: AgoraVideoViewSetupMode
        var mirrorMode: AgoraVideoMirrorMode
        var enableAlphaMask: Bool

        init(renderMode: AgoraVideoRenderMode = .hidden,
                    cropArea: CGRect = .zero,
                    setupMode: AgoraVideoViewSetupMode = .replace,
                    mirrorMode: AgoraVideoMirrorMode = .disabled,
                    enableAlphaMask: Bool = false) {
            self.renderMode = renderMode
            self.cropArea = cropArea
            self.setupMode = setupMode
            self.mirrorMode = mirrorMode
            self.enableAlphaMask = enableAlphaMask
        }
    }

    private var canvasProperties: CanvasProperties
    
    var renderMode: AgoraVideoRenderMode {
        get { canvasProperties.renderMode } set { canvasProperties.renderMode = newValue }
    }
    
    var cropArea: CGRect {
        get { canvasProperties.cropArea } set { canvasProperties.cropArea = newValue }
    }
    
    var setupMode: AgoraVideoViewSetupMode {
        get { canvasProperties.setupMode } set { canvasProperties.setupMode = newValue }
    }
    
    var enableAlphaMask: Bool {
        get { canvasProperties.enableAlphaMask } set { canvasProperties.enableAlphaMask = newValue }
    }
    
    var mirrorMode: AgoraVideoMirrorMode {
        get { canvasProperties.mirrorMode } set { canvasProperties.mirrorMode = newValue }
    }
    
    init(
        manager: CanvasViewHelper, uid: UInt,
        renderMode: AgoraVideoRenderMode = .hidden,
        cropArea: CGRect = .zero,
        setupMode: AgoraVideoViewSetupMode = .replace
    ) {
        self.init(
            manager: manager, canvasId: .userId(uid),
            canvasProps: CanvasProperties(renderMode: renderMode, cropArea: cropArea, setupMode: setupMode)
        )
    }
    
    init(
        manager: CanvasViewHelper,
        canvasId: CanvasIdType,
        canvasProps: CanvasProperties = CanvasProperties()
    ) {
        self.manager = manager
        self.canvasId = canvasId
        self.canvasProperties = canvasProps
    }

    private func createCanvasView() -> UIView {
        // Create and return the remote video view
        let canvasView = UIView()
        canvas.view = canvasView
        canvas.renderMode = canvasProperties.renderMode
        canvas.cropArea = canvasProperties.cropArea
        canvas.setupMode = canvasProperties.setupMode
        canvas.mirrorMode = canvasProperties.mirrorMode
        canvas.enableAlphaMask = canvasProperties.enableAlphaMask
        canvasView.isHidden = false
        if let manager {
            self.setUserId(to: self.canvasId, agoraEngine: manager.agoraEngine)
        }
        return canvasView
    }

    private func updateCanvasValues() {
        if canvas.renderMode != renderMode { canvas.renderMode = renderMode }
        if canvas.cropArea != cropArea { canvas.cropArea = cropArea }
        if canvas.setupMode != setupMode { canvas.setupMode = setupMode }
        if canvas.mirrorMode != mirrorMode { canvas.mirrorMode = mirrorMode }
        if canvas.enableAlphaMask != enableAlphaMask { canvas.enableAlphaMask = enableAlphaMask }
        if let manager {
            self.setUserId(to: self.canvasId, agoraEngine: manager.agoraEngine)
        }
    }
}
extension AgoraVideoCanvasView {
    public func makeUIView(context: Context) -> UIView {
        createCanvasView()
    }

    /// Updates the Canvas view.
    public func updateUIView(_ uiView: UIView, context: Context) {
        self.updateCanvasValues()
    }
}
