//
//  AgoraCameraSourcePushDelegate.swift
//  VideoCaller
//
//  Created by Kilo Loco on 2/1/24.
//

import UIKit
import AVFoundation
import AgoraRtcKit

protocol AgoraCameraSourcePushDelegate: AnyObject {
    func myVideoCapture(
        _ pixelBuffer: CVPixelBuffer,
        rotation: Int, timeStamp: CMTime
    )
    
    var previewLayer: AVCaptureVideoPreviewLayer? { get set }
}

class AgoraCameraSourcePush: NSObject {
    
    var videoDevice: AVCaptureDevice
    var onVideoFrameCaptured: ((_ pixelBuffer: CVPixelBuffer, _ rotation: Int, _ timeStamp: CMTime) -> Void)
    var previewLayer: AVCaptureVideoPreviewLayer?
    private let captureSession: AVCaptureSession
    private let captureQueue: DispatchQueue
    var currentOutput: AVCaptureVideoDataOutput? {
        (self.captureSession.outputs as? [AVCaptureVideoDataOutput])?.first
    }

    init(
        videoDevice: AVCaptureDevice,
        onVideoFrameCaptured: @escaping (
            _ pixelBuffer: CVPixelBuffer, _ rotation: Int, _ timeStamp: CMTime
        ) -> Void
    ) {
        self.videoDevice = videoDevice
        self.onVideoFrameCaptured = onVideoFrameCaptured
        self.captureSession = AVCaptureSession()
        self.captureSession.usesApplicationAudioSession = false

        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        if self.captureSession.canAddOutput(captureOutput) {
            self.captureSession.addOutput(captureOutput)
        }

        self.captureQueue = DispatchQueue(label: "AgoraCaptureQueue")
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    }

    deinit {
        self.captureSession.stopRunning()
    }

    func startCapturing() {
        guard let currentOutput = self.currentOutput else {
            return
        }

        currentOutput.setSampleBufferDelegate(self, queue: self.captureQueue)

        captureQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.setCaptureDevice(strongSelf.videoDevice, ofSession: strongSelf.captureSession)
            strongSelf.captureSession.beginConfiguration()
            if strongSelf.captureSession.canSetSessionPreset(.vga640x480) {
                strongSelf.captureSession.sessionPreset = .vga640x480
            }
            strongSelf.captureSession.commitConfiguration()
            strongSelf.captureSession.startRunning()
        }
    }

    /// Resumes capturing frames.
    func resumeCapture() {
        self.currentOutput?.setSampleBufferDelegate(self, queue: self.captureQueue)
        self.captureQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    /// Stops capturing frames.
    func stopCapturing() {
        self.currentOutput?.setSampleBufferDelegate(nil, queue: nil)
        self.captureQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
}

extension AgoraCameraSourcePush {
    func setCaptureDevice(_ device: AVCaptureDevice, ofSession captureSession: AVCaptureSession) {
        let currentInputs = captureSession.inputs as? [AVCaptureDeviceInput]
        let currentInput = currentInputs?.first

        if let currentInputName = currentInput?.device.localizedName,
            currentInputName == device.uniqueID {
            return
        }

        guard let newInput = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        captureSession.beginConfiguration()
        if let currentInput = currentInput {
            captureSession.removeInput(currentInput)
        }
        if captureSession.canAddInput(newInput) {
            captureSession.addInput(newInput)
        }
        captureSession.commitConfiguration()
    }
}

extension AgoraCameraSourcePush: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        DispatchQueue.main.async { [weak self] in
            let imgRot = UIDevice.current.orientation.intRotation
            self?.onVideoFrameCaptured(pixelBuffer, imgRot, time)
        }
    }
}

internal extension UIDeviceOrientation {
    func toCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        default: return .portrait
        }
    }
    
    var intRotation: Int {
        switch self {
        case .portrait: return 90
        case .landscapeLeft: return 0
        case .landscapeRight: return 180
        case .portraitUpsideDown: return -90
        default: return 90
        }
    }
}
