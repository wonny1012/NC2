//
//  VideoCapture.swift
//  NC2
//
//  Created by kwon ji won on 2022/08/30.
//

import Foundation

import AVKit
import UIKit

typealias VideoCaptureHandler = (_ sampleBUFFER: CVPixelBuffer) -> Void

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    var previewLayer: AVCaptureVideoPreviewLayer! = nil
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    private var isOutputAttached = false
    let previewView: UIView

    private let captureHandler: VideoCaptureHandler

    init(previewView: UIView, captureHandler: @escaping VideoCaptureHandler) {
        self.previewView = previewView
        self.captureHandler = captureHandler
    }

    public func getRootLayer() -> CALayer {
        return self.rootLayer

    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        self.captureHandler(pixelBuffer)
    }

    @discardableResult
    func setupAVCapture() -> Bool {
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first

        if let _ = videoDevice {

        } else {
            print("Could not create video device input, device possibly does not have camera access.")
            return false
        }

        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice!) else {
            print("Could not create video device input")
            return false
        }

        configureSession(session, deviceInput, videoDevice!)

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        return true
    }

    func switchCamera() {
        if /* session != nil && */ session.isRunning {
            guard let currentCameraInput: AVCaptureInput = session.inputs.first else {
                return
            }

            session.beginConfiguration()
            session.removeInput(currentCameraInput)
            session.commitConfiguration()

            var newCamera: AVCaptureDevice! = nil
            if let input = currentCameraInput as? AVCaptureDeviceInput {
                if (input.device.position == .back) {
                    UIView.transition(with: previewView, duration: 0.5, options: .transitionFlipFromLeft, animations: {
                        newCamera = self.cameraWithPosition(.front) }, completion: nil)
                }
                else {
                    UIView.transition(with: previewView, duration: 0.5, options: .transitionFlipFromRight, animations: {
                        newCamera = self.cameraWithPosition(.back) }, completion: nil)
                }
            }

            var err: NSError?
            var newVideoInput: AVCaptureDeviceInput!
            do {
                newVideoInput = try AVCaptureDeviceInput(device: newCamera)
            } catch let err1 as NSError {
                err = err1
                newVideoInput = nil
            }

            if newVideoInput == nil || err != nil {
                print("Error creating capture device input: \(String(describing: err?.localizedDescription))")
            } else {
                configureSession(session, newVideoInput, newCamera)
            }
        }
    }

    func cameraWithPosition(_ position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        for device in discoverySession.devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }

    func configureSession(_ session: AVCaptureSession, _ deviceInput: AVCaptureDeviceInput, _ videoDevice: AVCaptureDevice) {

        session.beginConfiguration()

        // configure camera quality
        session.sessionPreset = .vga640x480

        // add video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)

        // add video output
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            isOutputAttached = true
            // configure output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else if (!isOutputAttached) {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }

        let captureConnection = videoDataOutput.connection(with: .video)

        captureConnection?.isEnabled = true
        do {
            try  videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice.activeFormat.formatDescription))
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
    }

    func startCaptureSession() {
        session.startRunning()
    }

    func teardownAVCapture() {
        session.stopRunning()
    }

    public static func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation

        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }

}

