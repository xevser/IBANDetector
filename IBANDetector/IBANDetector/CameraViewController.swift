//
//  CameraViewController.swift
//  IBANDetector
//
//  Created by Kevser on 18.06.2021.
//


import AVFoundation
import CoreVideo
import MLKit

class CameraViewController: UIViewController {

    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)

    private var isUsingFrontCamera = false
    
    @IBOutlet private weak var cameraView: UIView!
    @IBOutlet private weak var lblResult: UILabel!
    
    var resultsText = ""
    var delegate : ViewControllerBackDelegate!
 
    private var lastFrame: CMSampleBuffer?
    
    private lazy var annotationOverlayView: UIView = {
      precondition(isViewLoaded)
      let annotationOverlayView = UIView(frame: .zero)
      annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return annotationOverlayView
    }()
    
    private lazy var previewOverlayView: UIImageView = {

      precondition(isViewLoaded)
      let previewOverlayView = UIImageView(frame: .zero)
      previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
      previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
      return previewOverlayView
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "IBAN Detector"
        
  
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpPreviewOverlayView()
        setUpAnnotationOverlayView()
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
    }
    
    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)

      startSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
      super.viewDidDisappear(animated)

      stopSession()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()

      previewLayer.frame = cameraView.frame
    }
    
    
    private func setUpCaptureSessionOutput() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.captureSession.beginConfiguration()
        // When performing latency tests to determine ideal capture settings,
        // run the app in 'release' mode to get accurate performance metrics
        strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
          (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
        output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
        //output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
        guard strongSelf.captureSession.canAddOutput(output) else {
          print("Failed to add capture session output.")
          return
        }
        strongSelf.captureSession.addOutput(output)
        strongSelf.captureSession.commitConfiguration()
      }
    }
    
    private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
      if #available(iOS 10.0, *) {
        let discoverySession = AVCaptureDevice.DiscoverySession(
          deviceTypes: [.builtInWideAngleCamera],
          mediaType: .video,
          position: .unspecified
        )
        return discoverySession.devices.first { $0.position == position }
      }
      return nil
    }

    private func setUpCaptureSessionInput() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
        guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
          print("Failed to get capture device for camera position: \(cameraPosition)")
          return
        }
        do {
          strongSelf.captureSession.beginConfiguration()
          let currentInputs = strongSelf.captureSession.inputs
          for input in currentInputs {
            strongSelf.captureSession.removeInput(input)
          }

          let input = try AVCaptureDeviceInput(device: device)
          guard strongSelf.captureSession.canAddInput(input) else {
            print("Failed to add capture session input.")
            return
          }
          strongSelf.captureSession.addInput(input)
          strongSelf.captureSession.commitConfiguration()
        } catch {
          print("Failed to create capture device input: \(error.localizedDescription)")
        }
      }
    }

    private func startSession() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.captureSession.startRunning()
      }
    }

    private func stopSession() {
      weak var weakSelf = self
      sessionQueue.async {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.captureSession.stopRunning()
      }
    }

    
   
    private func removeDetectionAnnotations() {
      for annotationView in annotationOverlayView.subviews {
        annotationView.removeFromSuperview()
      }
    }
    
    private func setUpPreviewOverlayView() {
      cameraView.addSubview(previewOverlayView)
      NSLayoutConstraint.activate([
        previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
        previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
        previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
        previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),

      ])
    }

    private func setUpAnnotationOverlayView() {
      cameraView.addSubview(annotationOverlayView)
      NSLayoutConstraint.activate([
        annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
        annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
        annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
        annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
      ])
    }
    
    private func updatePreviewOverlayViewWithLastFrame() {
    
      resultsText = ""
      guard let lastFrame = lastFrame,
        let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
      else {
        return
      }
      self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
    }
    
    private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
      guard let imageBuffer = imageBuffer else {
        return
      }
      let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
        let image = Utils.createUIImage(from: imageBuffer, orientation: orientation)
      previewOverlayView.image = image
    }

    
    private func recognizeTextOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
      var recognizedText: Text
      do {
        recognizedText = try TextRecognizer.textRecognizer().results(in: image)
      } catch let error {
        print("Failed to recognize text with error: \(error.localizedDescription).")
        return
      }
      weak var weakSelf = self
      DispatchQueue.main.sync {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        
        resultsText = recognizedText.text
       
        let validIban = resultsText.checkHasValidIban()
        if !validIban.isEmpty
        {
            lblResult.text = validIban
            delegate.showIban(iban: validIban)
            stopSession()
            self.navigationController?.popViewController(animated: true)
            return
        }
        
       strongSelf.updatePreviewOverlayViewWithLastFrame()
        strongSelf.removeDetectionAnnotations()

        // Blocks.
        for block in recognizedText.blocks {
          let points = strongSelf.convertedPoints(
            from: block.cornerPoints, width: width, height: height)
          Utils.addShape(
            withPoints: points,
            to: strongSelf.annotationOverlayView,
            color: UIColor.purple
          )

          // Lines.
          for line in block.lines {
            let points = strongSelf.convertedPoints(
              from: line.cornerPoints, width: width, height: height)
            Utils.addShape(
              withPoints: points,
              to: strongSelf.annotationOverlayView,
              color: UIColor.orange
            )

           
            for element in line.elements {
                
              let normalizedRect = CGRect(
                x: element.frame.origin.x / width,
                y: element.frame.origin.y / height,
                width: element.frame.size.width / width,
                height: element.frame.size.height / height
              )
              let convertedRect = strongSelf.previewLayer.layerRectConverted(
                fromMetadataOutputRect: normalizedRect
              )
              Utils.addRectangle(
                convertedRect,
                to: strongSelf.annotationOverlayView,
                color: UIColor.green
              )
              let label = UILabel(frame: convertedRect)
              label.text = element.text
              label.adjustsFontSizeToFitWidth = true
              strongSelf.rotate(label, orientation: image.orientation)
              strongSelf.annotationOverlayView.addSubview(label)
            }
          }
        }
      }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    private func rotate(_ view: UIView, orientation: UIImage.Orientation) {
      var degree: CGFloat = 0.0
      switch orientation {
      case .up, .upMirrored:
        degree = 90.0
      case .rightMirrored, .left:
        degree = 180.0
      case .down, .downMirrored:
        degree = 270.0
      case .leftMirrored, .right:
        degree = 0.0
      }
      view.transform = CGAffineTransform.init(rotationAngle: degree * 3.141592654 / 180)
    }
    
    private func convertedPoints(
      from points: [NSValue]?,
      width: CGFloat,
      height: CGFloat
    ) -> [NSValue]? {
      return points?.map {
        let cgPointValue = $0.cgPointValue
        let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
        let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
        let value = NSValue(cgPoint: cgPoint)
        return value
      }
    }

}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to get image buffer from sample buffer.")
      return
    }
   
    lastFrame = sampleBuffer
    let visionImage = VisionImage(buffer: sampleBuffer)
    let orientation = Utils.imageOrientation(
      fromDevicePosition: isUsingFrontCamera ? .front : .back
    )

    visionImage.orientation = orientation
    let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
    let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))

    recognizeTextOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
  }
}

private enum Constant {
  static let alertControllerTitle = "Vision Detectors"
  static let alertControllerMessage = "Select a detector"
  static let cancelActionTitleText = "Cancel"
  static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
  static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
  static let noResultsMessage = "No Results"
  static let localModelFile = (name: "bird", type: "tflite")
  static let labelConfidenceThreshold = 0.75
  static let smallDotRadius: CGFloat = 4.0
  static let lineWidth: CGFloat = 3.0
  static let originalScale: CGFloat = 1.0
  static let padding: CGFloat = 10.0
  static let resultsLabelHeight: CGFloat = 200.0
  static let resultsLabelLines = 5
  static let imageLabelResultFrameX = 0.4
  static let imageLabelResultFrameY = 0.1
  static let imageLabelResultFrameWidth = 0.5
  static let imageLabelResultFrameHeight = 0.8
  static let segmentationMaskAlpha: CGFloat = 0.5
}
