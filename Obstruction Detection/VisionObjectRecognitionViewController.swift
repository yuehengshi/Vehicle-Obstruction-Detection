//
//  VisionObjectRecognitionViewController.swift
//  Obstruction Detection
//
//  Created by Yueheng Shi on 2024-11-26.
//

import UIKit
import AVFoundation
import Vision

class VisionObjectRecognitionViewController: ViewController {
    
    private var detectionOverlay: CALayer! = nil
    private var alertLabel: UILabel! = nil
    private var obstacleLabel: UILabel! = nil
    private var brightnessLabel: UILabel! = nil
    private let stencilImage = UIImage(named: "stencil")!
    private var stencilImageView: UIImageView! = nil
    var cannotFindVehicleCount = 0
    var hasObstacleCount = 0
    // Vision parts
    private var requests = [VNRequest]()
    
    @discardableResult
    func setupVision() -> NSError? {
        // Setup Vision parts
        let error: NSError! = nil
        
        guard let modelURL = Bundle.main.url(forResource: "yolov8s", withExtension: "mlmodelc") else {
            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.drawVisionRequestResults(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
        return error
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        var largestVehicleBound = CGRect()
        var topLabelObservationIdentifier = ""
        var obstacles = [Obstacle]()
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            if ["car", "truck"].contains(topLabelObservation.identifier) {
                let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
                if largestVehicleBound.width * largestVehicleBound.height < objectBounds.width * objectBounds.height {
                    largestVehicleBound = objectBounds
                }
            } else {
                let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
                let obstacle = Obstacle()
                obstacle.identifier = topLabelObservation.identifier
                obstacle.frame = objectBounds
                obstacles.append(obstacle)
            }
        }
//        let shapeLayer = self.createRoundedRectLayerWithBounds(largestVehicleBound)
//
//        if shapeLayer.bounds.width >= 700 && shapeLayer.bounds.height >= 500 {
//            let textLayer = self.createTextSubLayerInBounds(largestVehicleBound,
//                                                            identifier: topLabelObservationIdentifier,
//                                                            confidence: 0)
//            shapeLayer.addSublayer(textLayer)
//            detectionOverlay.addSublayer(shapeLayer)
//            updateAlert(objectShapeBound: largestVehicleBound, confidence: 0)
//        }
        
        let shapeLayer = self.createRoundedRectLayerWithBounds(largestVehicleBound)
        print(shapeLayer.bounds)
        if checkSize(objectShapeBound: largestVehicleBound) {
            let textLayer = self.createTextSubLayerInBounds(largestVehicleBound,
                                                            identifier: topLabelObservationIdentifier,
                                                            confidence: 0)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
            if checkPosition(objectShapeBound: largestVehicleBound, confidence: 0) {
                checkObstacles(obstacles: obstacles, vehicleFrame: largestVehicleBound)
            }
        }
//        if shapeLayer.bounds.width >= 700 && shapeLayer.bounds.height >= 500 {
//            let textLayer = self.createTextSubLayerInBounds(largestVehicleBound,
//                                                            identifier: topLabelObservationIdentifier,
//                                                            confidence: 0)
//            shapeLayer.addSublayer(textLayer)
//            detectionOverlay.addSublayer(shapeLayer)
//            if checkPosition(objectShapeBound: largestVehicleBound, confidence: 0) {
//                checkObstacles(obstacles: obstacles, vehicleFrame: largestVehicleBound)
//            }
//        }
        for obstacle in obstacles {
            let shapeLayer = self.createRoundedRectLayerWithBounds(obstacle.frame)
            let textLayer = self.createTextSubLayerInBounds(obstacle.frame,
                                                            identifier: obstacle.identifier,
                                                            confidence: 0)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
            checkObstacles(obstacles: obstacles, vehicleFrame: largestVehicleBound)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        checkBrightness(sampleBuffer: sampleBuffer)
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    override func setupAVCapture() {
        super.setupAVCapture()
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        setupVision()
        
        // start the capture
        startCaptureSession()
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)

        stencilImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: rootLayer.bounds.width, height: rootLayer.bounds.height))
//        stencilImageView.transform = CGAffineTransform(rotationAngle: .pi * 0.5)
        stencilImageView.center = rootLayer.position
        stencilImageView.image = stencilImage
        stencilImageView.contentMode = .scaleAspectFit
        self.view.addSubview(stencilImageView)
        
        alertLabel = UILabel(frame: CGRect(x: 100, y: 100, width: 400, height: 30))
        alertLabel.textAlignment = .center
        alertLabel.font = UIFont(name: "Helvetica", size: 22.0)
        alertLabel.center = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.maxY - 30)
//        alertLabel.transform = CGAffineTransform(rotationAngle: .pi * 0.5)
        self.view.addSubview(alertLabel)
        
        obstacleLabel = UILabel(frame: CGRect(x: 100, y: 100, width: 400, height: 30))
        obstacleLabel.textAlignment = .center
        obstacleLabel.font = UIFont(name: "Helvetica", size: 22.0)
        obstacleLabel.center = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.maxY - 65)
//        obstacleLabel.transform = CGAffineTransform(rotationAngle: .pi * 0.5)
        obstacleLabel.text = "Obstacle Detected"
        obstacleLabel.backgroundColor = UIColor.red
        self.view.addSubview(obstacleLabel)
        
        brightnessLabel = UILabel(frame: CGRect(x: 100, y: 100, width: 400, height: 30))
        brightnessLabel.textAlignment = .center
        brightnessLabel.font = UIFont(name: "Helvetica", size: 22.0)
        brightnessLabel.center = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.minY + 15)
//        brightnessLabel.transform = CGAffineTransform(rotationAngle: .pi * 0.5)
        brightnessLabel.backgroundColor = UIColor.red
        brightnessLabel.isHidden = true
        brightnessLabel.text = "Too dark"
        self.view.addSubview(brightnessLabel)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.width
        let yScale: CGFloat = bounds.size.height / bufferSize.height
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
//        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func checkSize(objectShapeBound: CGRect) -> Bool {
        var vehicleSizeOkay = true
        if objectShapeBound.height < 700 || objectShapeBound.height > 1100 {
            vehicleSizeOkay = false
        }
        if vehicleSizeOkay {
            alertLabel.backgroundColor = UIColor.green
            alertLabel.isHidden = true
            alertLabel.text = ""
        } else {
            alertLabel.backgroundColor = UIColor.red
            alertLabel.isHidden = false
            alertLabel.text = "Please Fit Vehicle In Stencil"
        }
        return vehicleSizeOkay
    }
    
    func checkObstacles(obstacles: [Obstacle], vehicleFrame: CGRect) {
        var hasObstacle = false
        for obstacle in obstacles {
//            if vehicleFrame.intersects(obstacle.frame) && areaOfFrame(frame: vehicleFrame) > areaOfFrame(frame: obstacle.frame) {
            if vehicleFrame.intersects(obstacle.frame) && !(obstacle.frame.width * 0.8 > vehicleFrame.width && obstacle.frame.height * 0.8 > vehicleFrame.height) {
                let shapeLayer = self.createRoundedRectLayerWithBounds(obstacle.frame)
                let textLayer = self.createTextSubLayerInBounds(obstacle.frame,
                                                                identifier: obstacle.identifier,
                                                                confidence: 0)
                shapeLayer.addSublayer(textLayer)
                detectionOverlay.addSublayer(shapeLayer)
                hasObstacle = true
            }
        }
        if hasObstacle {
            hasObstacleCount += 1
        } else {
            hasObstacleCount = 0
        }
        obstacleLabel.isHidden = hasObstacleCount < 10
        print(hasObstacleCount)
    }
    
    func checkPosition(objectShapeBound: CGRect, confidence : Float) -> Bool {
        var vehiclePositionOkay = true
        var string = ""
//        if (800...1100).contains(objectShapeBound.width) && (600...900).contains(objectShapeBound.height){
            cannotFindVehicleCount = 0
            if objectShapeBound.midX - detectionOverlay.bounds.midX > 300 {
                string = "Please move device right"
                vehiclePositionOkay = false
            }
            if objectShapeBound.midX - detectionOverlay.bounds.midX < -300 {
                string = "Please move device left"
                vehiclePositionOkay = false
            }
            if objectShapeBound.midY - detectionOverlay.bounds.midY > 200 {
                string = "Please move device top"
                vehiclePositionOkay = false
            }
            if objectShapeBound.midY - detectionOverlay.bounds.midY < -200 {
                string = "Please move device bottom"
                vehiclePositionOkay = false
            }
//        } else {
//            cannotFindVehicleCount += 1
//        }

//        else if !(0...500).contains(objectShapeBound.width) || !(0...500).contains(objectShapeBound.height){
//            string = "Please adjust the vehicle's position"
//            print(objectShapeBound.width, objectShapeBound.height)
//        }
//        else if objectShapeBound.width < 1000 || objectShapeBound.height < 700 {
//            string = "Please move vehicle closer"
//        } else if objectShapeBound.width > 1500 || objectShapeBound.height > 1200 {
//            string = "Please move vehicle further"
//        }
        if vehiclePositionOkay {
            alertLabel.backgroundColor = UIColor.green
            alertLabel.isHidden = true
        } else {
            string = "Please Fit Vehicle In Stencil"
            alertLabel.backgroundColor = UIColor.red
            if !string.isEmpty {
                alertLabel.isHidden = false
                alertLabel.text = string
            } else {
                print(cannotFindVehicleCount)
//                if cannotFindVehicleCount > 15 {
                    alertLabel.isHidden = true
                    alertLabel.text = ""
//                }
            }
        }
        return vehiclePositionOkay
    }
    
    func areaOfFrame(frame: CGRect) -> CGFloat {
        return frame.size.width * frame.size.height
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
//        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
//        shapeLayer.bounds = bounds
//        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
//        shapeLayer.name = "Found Object"
//        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
//        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    func checkBrightness(sampleBuffer: CMSampleBuffer) {
        let rawMetadata = CMCopyDictionaryOfAttachments(allocator: nil, target: sampleBuffer, attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate))
        let metadata = CFDictionaryCreateMutableCopy(nil, 0, rawMetadata) as NSMutableDictionary
        let exifData = metadata.value(forKey: "{Exif}") as? NSMutableDictionary
        let brightnessValue : Double = exifData?[kCGImagePropertyExifBrightnessValue as String] as! Double
        print("🌞: ", brightnessValue)
        DispatchQueue.main.async {
            self.brightnessLabel.isHidden = brightnessValue > 2
        }
    }
}

class Obstacle {
    var identifier : String = ""
    var frame : CGRect = CGRect()
}

