//
//  ViewController.swift
//  IBANDetector
//
//  Created by Kevser on 18.06.2021.
//

import UIKit
import MLKit

protocol ViewControllerBackDelegate {
    func showIban(iban:String)
}

class ViewController: UIViewController, UINavigationControllerDelegate {
    
    @IBOutlet fileprivate weak var imageView: UIImageView!
    @IBOutlet fileprivate weak var lblResult: UILabel!
    @IBOutlet fileprivate weak var btnCopy: UIButton!
    
    var imagePicker = UIImagePickerController()
    
    var resultsText = ""
    var foundText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "IBAN Detector"
        
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        imagePicker.allowsEditing = true
    }
    
    @IBAction func openCamera()
    {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyBoard.instantiateViewController(withIdentifier:"CameraViewController") as! CameraViewController
        vc.delegate = self
        self.navigationController!.pushViewController(vc, animated: true)
    }
    
    @IBAction func openGallery()
    {
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func copyText()
    {
        UIPasteboard.general.string = foundText
        btnCopy.setTitle("Copied", for: .normal)
    }
    
    private func clearResults() {
    
        self.resultsText = ""
    }
    
    
    @IBAction func detect()
    {
        clearResults()
        detectTextOnDevice(image: imageView.image)
    }
    
    func detectTextOnDevice(image: UIImage?) {
        guard let image = image else { return }
        
        // [START init_text]
        let onDeviceTextRecognizer = TextRecognizer.textRecognizer()
        // [END init_text]
        
        // Initialize a `VisionImage` object with the given `UIImage`.
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        
        self.resultsText += "Running On-Device Text Recognition...\n"
        process(visionImage, with: onDeviceTextRecognizer)
    }
    
    
    private func process(_ visionImage: VisionImage, with textRecognizer: TextRecognizer?) {
        weak var weakSelf = self
        textRecognizer?.process(visionImage) { text, error in
            guard let strongSelf = weakSelf else {
                print("Self is nil!")
                return
            }
            guard error == nil, let text = text else {
                let errorString = error?.localizedDescription ?? Constants.detectionNoResultsMessage
                strongSelf.resultsText = "Text recognizer failed with error: \(errorString)"
                return
            }
           
            strongSelf.resultsText += "\(text.text)\n"
            strongSelf.foundText = strongSelf.resultsText.checkHasValidIban()
            strongSelf.fillLabel()
        }
    }

    
    func fillLabel()
    {
        lblResult.text = foundText.isEmpty ? "No valid IBAN found" : foundText.formattedIBANWithTR()
        
       if !foundText.isEmpty
       {
         copyText()
       }
    }

    private func updateImageView(with image: UIImage) {
        let orientation = UIApplication.shared.statusBarOrientation
        var scaledImageWidth: CGFloat = 0.0
        var scaledImageHeight: CGFloat = 0.0
        switch orientation {
        case .portrait, .portraitUpsideDown, .unknown:
            scaledImageWidth = imageView.bounds.size.width
            scaledImageHeight = image.size.height * scaledImageWidth / image.size.width
        case .landscapeLeft, .landscapeRight:
            scaledImageWidth = image.size.width * scaledImageHeight / image.size.height
            scaledImageHeight = imageView.bounds.size.height
        @unknown default:
            fatalError()
        }
        weak var weakSelf = self
        DispatchQueue.global(qos: .userInitiated).async {
            // Scale image while maintaining aspect ratio so it displays better in the UIImageView.
            var scaledImage = image.scaledImage(
                with: CGSize(width: scaledImageWidth, height: scaledImageHeight)
            )
            scaledImage = scaledImage ?? image
            guard let finalImage = scaledImage else { return }
            DispatchQueue.main.async {
                weakSelf?.imageView.image = finalImage
                self.detect()
            }
        }
    }
    
}

extension ViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        clearResults()
        if let pickedImage =
            info[
                convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)]
            as? UIImage
        {
            updateImageView(with: pickedImage)
        }
        dismiss(animated: true)
    }
    
    private func convertFromUIImagePickerControllerInfoKeyDictionary(
        _ input: [UIImagePickerController.InfoKey: Any]
    ) -> [String: Any] {
        return Dictionary(uniqueKeysWithValues: input.map { key, value in (key.rawValue, value) })
    }
    
    // Helper function inserted by Swift 4.2 migrator.
    private func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey)
    -> String
    {
        return input.rawValue
    }
    
}

extension ViewController : ViewControllerBackDelegate
{
    func showIban(iban:String)
    {
        foundText = iban
        fillLabel()
    }
}
