//
//  Extensions.swift
//  IBANDetector
//
//  Created by Kevser on 18.06.2021.
//

import UIKit

extension UIImage {

  /// Creates and returns a new image scaled to the given size. The image preserves its original PNG
  /// or JPEG bitmap info.
  ///
  /// - Parameter size: The size to scale the image to.
  /// - Returns: The scaled image or `nil` if image could not be resized.
  public func scaledImage(with size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    defer { UIGraphicsEndImageContext() }
    draw(in: CGRect(origin: .zero, size: size))
    return UIGraphicsGetImageFromCurrentImageContext()?.data.flatMap(UIImage.init)
  }

  // MARK: - Private

  /// The PNG or JPEG data representation of the image or `nil` if the conversion failed.
  private var data: Data? {
    #if swift(>=4.2)
      return self.pngData() ?? self.jpegData(compressionQuality: Constants.jpegCompressionQuality)
    #else
      return self.pngData() ?? self.jpegData(compressionQuality: Constants.jpegCompressionQuality)
    #endif  // swift(>=4.2)
  }
}

// MARK: - Constants


extension CGRect {
  /// Returns a `Bool` indicating whether the rectangle's values are valid`.
  func isValid() -> Bool {
    return
      !(origin.x.isNaN || origin.y.isNaN || width.isNaN || height.isNaN || width < 0 || height < 0
      || origin.x < 0 || origin.y < 0)
  }
}


extension String {
    
    func isValidIBAN() -> Bool {
        
        if self.hasPrefix("TR")
        {
            let temp = self.replacingOccurrences(of: " ", with: "")
            if  temp.count == 26
            {
                let ibanRegEx = "[a-zA-Z]{2}+[0-9]{2}+[a-zA-Z0-9]{4}+[0-9]{7}([a-zA-Z0-9]?){0,16}"
                let ibanTest = NSPredicate(format:"SELF MATCHES %@", ibanRegEx)
                return ibanTest.evaluate(with: temp)
            }
        }
        return false
   }
    
    func checkHasValidIban()-> String
    {
        let arr = self.split(separator: "\n")
        for i in 0..<arr.count
        {
            let text = arr[i]
            if !text.isEmpty
            {
                if String(text).isValidIBAN()
                {
                    print("valid---> " + String(text))
                    return String(text)
                }
                print("not valid---> " + String(text))
            }
        }
       return ""
    }
    
    func formattedIBANWithTR() -> String {
        let cleanIban = self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        let mask = "**** **** **** **** **** **** **"

        var result = ""
        var index = cleanIban.startIndex
        for ch in mask where index < cleanIban.endIndex {
            if ch == "*" {
                result.append(cleanIban[index])
                index = cleanIban.index(after: index)
            } else {
                result.append(ch)
            }
        }

        return (result.count > 1 ? result : ("TR" + result)).uppercased()
    }
    
}
