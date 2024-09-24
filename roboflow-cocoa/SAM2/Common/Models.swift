//
//  Models.swift
//  SAM2-Demo
//
//  Created by Cyril Zakka on 8/19/24.
//

import Foundation
import SwiftUI

enum SAMCategoryType: Int {
    case background = 0
    case foreground = 1
    case boxOrigin = 2
    case boxEnd = 3

    var description: String {
        switch self {
        case .foreground:
            return "Foreground"
        case .background:
            return "Background"
        case .boxOrigin:
            return "Box Origin"
        case .boxEnd:
            return "Box End"
        }
    }
}

struct SAMCategory: Hashable {
    let id: UUID = UUID()
    let type: SAMCategoryType
    let name: String
    let iconName: String
    let color: Color

    var typeDescription: String {
        type.description
    }

    static let foreground = SAMCategory(
        type: .foreground,
        name: "Foreground",
        iconName: "square.on.square.dashed",
        color: .pink
    )

    static let background = SAMCategory(
        type: .background,
        name: "Background",
        iconName: "square.on.square.intersection.dashed",
        color: .purple
    )

    static let boxOrigin = SAMCategory(
        type: .boxOrigin,
        name: "Box Origin",
        iconName: "",
        color: .white
    )

    static let boxEnd = SAMCategory(
        type: .boxEnd,
        name: "Box End",
        iconName: "",
        color: .white
    )
}
#if !os(macOS)
extension CGPoint: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.x)
        hasher.combine(self.y)
    }
}
#endif

struct SAMPoint: Hashable {
    let id = UUID()
    let coordinates: CGPoint
    let category: SAMCategory
    let dateAdded = Date()
}

struct SAMBox: Hashable, Identifiable {
    let id = UUID()
    var startPoint: CGPoint
    var endPoint: CGPoint
    let category: SAMCategory
    let dateAdded = Date()
    var midpoint: CGPoint {
        return CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }
}

extension SAMBox {
    var points: [SAMPoint] {
        [SAMPoint(coordinates: startPoint, category: .boxOrigin), SAMPoint(coordinates: endPoint, category: .boxEnd)]
    }
}

struct SAMSegmentation: Hashable, Identifiable {
    let id = UUID()
    var image: CIImage
    var tintColor: Color {
        didSet {
            updateTintedImage()
        }
    }
    var title: String = ""
    var firstAppearance: Int?
    var isHidden: Bool = false
    var shouldCropForAutoAnnotate: Bool = false
    private var tintedImage: CIImage?

    init(image: CIImage, tintColor: Color = Color(.sRGB, red: 30/255, green: 144/255, blue: 1), title: String = "", firstAppearance: Int? = nil, isHidden: Bool = false) {
        self.image = image
        self.tintColor = tintColor
        self.title = title
        self.firstAppearance = firstAppearance
        self.isHidden = isHidden
        updateTintedImage()
    }

    private mutating func updateTintedImage() {
        #if os(macOS)
        let ciColor = CIColor(color: NSColor(tintColor))
        #else
        let ciColor = CIColor(color: UIColor(tintColor))
        #endif
        let monochromeFilter = CIFilter.colorMonochrome()
        monochromeFilter.inputImage = image
        #if os(macOS)
        monochromeFilter.color = ciColor!
        #else
        monochromeFilter.color = ciColor
        #endif
        
        monochromeFilter.intensity = 1.0
        tintedImage = monochromeFilter.outputImage
    }

    var cgImage: CGImage {
        let context = CIContext()
        return context.createCGImage(tintedImage ?? image, from: (tintedImage ?? image).extent)!
    }
}

struct SAMTool: Hashable {
    let id: UUID = UUID()
    let name: String
    let iconName: String
}

// Tools
let pointTool: SAMTool = SAMTool(name: "Point", iconName: "hand.point.up.left")
let boundingBoxTool: SAMTool = SAMTool(name: "Bounding Box", iconName: "rectangle.dashed")

import Vision

extension SAMSegmentation {
    func getCGPath(originalImageSize: CGSize) -> CGPath? {
        let maskCGImage = cgImage
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = false // Adjust based on your mask
        request.maximumImageDimension = Int(max(maskCGImage.width, maskCGImage.height))
        
        let handler = VNImageRequestHandler(cgImage: maskCGImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                print("No contours detected in the mask image.")
                return nil
            }
            let normalized = observation.normalizedPath
            return CGPath(rect: CGRect(x: normalized.boundingBox.minX * CGFloat(maskCGImage.width),
                                       y: normalized.boundingBox.minY * CGFloat(maskCGImage.width),
                                       width: normalized.boundingBox.width * CGFloat(maskCGImage.width),
                                       height: normalized.boundingBox.height * CGFloat(maskCGImage.height)), transform: nil)
//            let maskWidth = CGFloat(maskCGImage.width)
//            let maskHeight = CGFloat(maskCGImage.height)
//            let imageWidth = originalImageSize.width
//            let imageHeight = originalImageSize.height
//            
//            // Create a transform to scale from normalized coordinates to mask coordinates
//            var transform = CGAffineTransform(scaleX: maskWidth, y: maskHeight)
//            // Apply the transform to the normalized path
//            let maskPath = observation.normalizedPath.copy(using: &transform)
//            
//            // Now create a transform to scale from mask coordinates to original image coordinates
//            var scaleTransform = CGAffineTransform(scaleX: imageWidth / maskWidth, y: imageHeight / maskHeight)
//            // Apply the scale transform
//            let transformedPath = maskPath?.copy(using: &scaleTransform)
//            
//            return transformedPath
        } catch {
            print("Error detecting contours: \(error)")
            return nil
        }
    }
    
    func getTransformedCGPath() -> CGPath? {
        let maskCGImage = cgImage
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.detectsDarkOnLight = false // Adjust based on your mask
        request.maximumImageDimension = Int(max(maskCGImage.width, maskCGImage.height))
        
        let handler = VNImageRequestHandler(cgImage: maskCGImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                print("No contours detected in the mask image.")
                return nil
            }

            let normalizedPath = observation.normalizedPath
            // Create a transform to flip the y-axis
            var transform = CGAffineTransform(scaleX: 1, y: -1)
            // Translate the path to adjust the origin
            transform = transform.translatedBy(x: 0, y: -1)
            
            // Apply the transform to the normalized path
            guard let transformedPath = normalizedPath.copy(using: &transform) else {
                print("Failed to transform normalized path.")
                return nil
            }
            
            return transformedPath
        } catch {
            print("Error detecting contours: \(error)")
            return nil
        }
    }
}

