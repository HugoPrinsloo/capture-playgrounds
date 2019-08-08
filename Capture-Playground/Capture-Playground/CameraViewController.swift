//
//  CameraViewController.swift
//  Capture-Playground
//
//  Created by Hugo Prinsloo on 2019/08/08.
//  Copyright © 2019 Hugo. All rights reserved.
//

import UIKit
import Photos
import AVFoundation

class CameraController: UIViewController {
    
    enum PhotoType {
        case jpeg
    }
    
    var currentPhotoType: PhotoType = .jpeg
    
    private var captureSession = AVCaptureSession()
    private let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .unspecified)
    private var capturePhotoOutput = AVCapturePhotoOutput()
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var currentDevice: AVCaptureDevice?
    // Use this preview to view camera view
    private let previewView = UIView()
    private let focusPointImageView: UIImageView = {
        let i = UIImageView(image: UIImage(named: "FocusIcon"))
        i.translatesAutoresizingMaskIntoConstraints = false
        i.widthAnchor.constraint(equalToConstant: 40).isActive = true
        i.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return i
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(previewView)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.fillSuperview()
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(focus(with:)))
        previewView.addGestureRecognizer(gesture)
        
        view.addSubview(focusPointImageView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        focusPointImageView.alpha = 0
        requestCaptureDeviceAuthorization()
        requestPhotoLibraryAccess()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        focusPointImageView.center = view.center
    }
    
    func capturePhoto() {
        let settings: AVCapturePhotoSettings
        switch currentPhotoType {
        case .jpeg:
            settings = configureJPEGCaptureSettings()
        }
        capturePhotoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    
}

// - MARK: Authorization
extension CameraController {
    
    private func requestCaptureDeviceAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            prepareForCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.prepareForCapture()
                }
            }
        case .denied:
        break // user denied access previously
        case .restricted:
        break // user can't grant access due to restrictions
        @unknown default:
            print("Unknown result for requestCaptureDeviceAuthorization()")
        }
    }
    
    private func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
            break // user can perform changes
            case .denied:
            break // user denied access
            case .notDetermined:
            break // user need to grant access
            case .restricted:
            break // user can't grant access due to restrictions
            @unknown default:
                print("Unknown result for requestPhotoLibraryAccess()")
            }
        }
    }
}

// - MARK: CaptureSession
 

// - MARK: CapturePhotoOutput

extension CameraController: AVCapturePhotoCaptureDelegate {
    
    private func configureJPEGCaptureSettings() -> AVCapturePhotoSettings {
        let photoSettings: AVCapturePhotoSettings
        photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoSettings.flashMode = .off
        photoSettings.isHighResolutionPhotoEnabled = false
        return photoSettings
    }
    
    private func configureHEVCCaptureSettings() -> AVCapturePhotoSettings {
        let photoSettings: AVCapturePhotoSettings
        photoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSettings.flashMode = .off
        photoSettings.isHighResolutionPhotoEnabled = false
        return photoSettings
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else { print("Error capturing photo: \(error!)"); return }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else { return }

            PHPhotoLibrary.shared().performChanges({
                // Add the captured photo's file data as the main resource for the Photos asset.
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: photo.fileDataRepresentation()!, options: nil)
            }, completionHandler: nil)
        }
    }
}


extension CameraController {
    private func prepareForCapture() {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        guard let cameraToUse = getCamera()
            else {
                print("No Camera Device")
                return//fatalError("Missing expected back camera device.")
        }
        do {
            let input = try AVCaptureDeviceInput(device: cameraToUse)
            capturePhotoOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(capturePhotoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(capturePhotoOutput)
                captureSession.commitConfiguration()
                currentDevice = cameraToUse
                setupLivePreview()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.animateOnStart()
                }
            }
            
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }
    
    private func getCamera() -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return device
        } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        } else {
            print("No Camera Device")
            return nil
        }
    }
    
    private func setupLivePreview() {
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .portrait
        previewView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.previewView.bounds
            }
            self.captureSession.startRunning()
        }
    }
}

// -MARK: Focus with animation
extension CameraController {
    @objc private func focus(with tap: UITapGestureRecognizer) {
        let location = tap.location(in: previewView)
        if let device = currentDevice {
            var pointOfInterest = CGPoint(x: 0.5, y: 0.5)
            let frameSize = previewView.frame.size
            pointOfInterest = CGPoint(x: location.y / frameSize.height, y: 1.0 - (location.x / frameSize.width))
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                try? device.lockForConfiguration()
                device.focusPointOfInterest = pointOfInterest
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposurePointOfInterest = pointOfInterest
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            animateFocusPointUI(to: location)
        }
    }
    
    private func animateOnStart() {
        focusPointImageView.alpha = 1
        let sizeToGrow: CGFloat = 1.5
        let animationDuration = 0.4
        
        let scaleAnimator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 20)
        scaleAnimator.addAnimations({
            self.focusPointImageView.transform = CGAffineTransform(scaleX: sizeToGrow, y: sizeToGrow)
        }, delayFactor: 0)
        scaleAnimator.addCompletion { (_) in
            let shrinkAnimator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.8) {
                self.focusPointImageView.transform = CGAffineTransform(scaleX: sizeToGrow, y: sizeToGrow)
            }
            shrinkAnimator.addCompletion { (_) in
                let finalAnimator = UIViewPropertyAnimator(duration: animationDuration, dampingRatio: 0.8) {
                    self.focusPointImageView.transform = .identity
                }
                finalAnimator.addCompletion { (_) in
                    self.focusPointImageView.alpha = 0
                }
                finalAnimator.startAnimation()
            }
            shrinkAnimator.startAnimation()
        }
        scaleAnimator.startAnimation()
    }
    
    private func animateFocusPointUI(to point: CGPoint) {
        UIView.animate(withDuration: 0, delay: 0, usingSpringWithDamping: 0, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
            self.focusPointImageView.alpha = 1
            self.focusPointImageView.center = point
        })
        UIView.animate(withDuration: 0.15, delay: 0.5, options: .curveEaseIn, animations: {
            self.focusPointImageView.alpha = 0
        })
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        previewView.alpha = 0
        UIView.animate(withDuration: 0.6) {
            self.previewView.alpha = 1
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?, previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
    }
}

extension CameraController {
    func setWhiteBalance() {
    }
}
