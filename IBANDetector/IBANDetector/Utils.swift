//
//  Constants.swift
//  IBANDetector
//
//  Created by Kevser on 18.06.2021.
//

import AVFoundation
import UIKit

public enum Constants {
  static let detectionNoResultsMessage = "No results returned."
  static let circleViewAlpha: CGFloat = 0.7
  static let rectangleViewAlpha: CGFloat = 0.3
  static let shapeViewAlpha: CGFloat = 0.3
  static let rectangleViewCornerRadius: CGFloat = 10.0
  static let maxColorComponentValue: CGFloat = 255.0
  static let originalScale: CGFloat = 1.0
  static let bgraBytesPerPixel = 4
  static let jpegCompressionQuality: CGFloat = 0.8
}

class Utils
{
    public static func createUIImage(
      from imageBuffer: CVImageBuffer,
      orientation: UIImage.Orientation
    ) -> UIImage? {
      let ciImage = CIImage(cvPixelBuffer: imageBuffer)
      let context = CIContext(options: nil)
      guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
      return UIImage(cgImage: cgImage, scale: Constants.originalScale, orientation: orientation)
    }
    
    public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
      guard rectangle.isValid() else { return }
      let rectangleView = UIView(frame: rectangle)
      rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
      rectangleView.alpha = Constants.rectangleViewAlpha
      rectangleView.backgroundColor = color
      view.addSubview(rectangleView)
    }

    public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor) {
      guard let points = points else { return }
      let path = UIBezierPath()
      for (index, value) in points.enumerated() {
        let point = value.cgPointValue
        if index == 0 {
          path.move(to: point)
        } else {
          path.addLine(to: point)
        }
        if index == points.count - 1 {
          path.close()
        }
      }
      let shapeLayer = CAShapeLayer()
      shapeLayer.path = path.cgPath
      shapeLayer.fillColor = color.cgColor
      let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
      let shapeView = UIView(frame: rect)
      shapeView.alpha = Constants.shapeViewAlpha
      shapeView.layer.addSublayer(shapeLayer)
      view.addSubview(shapeView)
    }

    public static func imageOrientation(
      fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
      var deviceOrientation = UIDevice.current.orientation
      if deviceOrientation == .faceDown || deviceOrientation == .faceUp
        || deviceOrientation
          == .unknown
      {
        deviceOrientation = currentUIOrientation()
      }
      switch deviceOrientation {
      case .portrait:
        return devicePosition == .front ? .leftMirrored : .right
      case .landscapeLeft:
        return devicePosition == .front ? .downMirrored : .up
      case .portraitUpsideDown:
        return devicePosition == .front ? .rightMirrored : .left
      case .landscapeRight:
        return devicePosition == .front ? .upMirrored : .down
      case .faceDown, .faceUp, .unknown:
        return .up
      @unknown default:
        fatalError()
      }
    }
    
    private static func currentUIOrientation() -> UIDeviceOrientation {
      let deviceOrientation = { () -> UIDeviceOrientation in
        switch UIApplication.shared.statusBarOrientation {
        case .landscapeLeft:
          return .landscapeRight
        case .landscapeRight:
          return .landscapeLeft
        case .portraitUpsideDown:
          return .portraitUpsideDown
        case .portrait, .unknown:
          return .portrait
        @unknown default:
          fatalError()
        }
      }
      guard Thread.isMainThread else {
        var currentOrientation: UIDeviceOrientation = .portrait
        DispatchQueue.main.sync {
          currentOrientation = deviceOrientation()
        }
        return currentOrientation
      }
      return deviceOrientation()
    }
  
}

