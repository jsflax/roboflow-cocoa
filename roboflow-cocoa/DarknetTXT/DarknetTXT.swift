import Foundation

func normalizeCoordinate(_ value: CGFloat, max: CGFloat) -> CGFloat {
    return value / max
}

import Vision

class DarknetTXT {
    static func computeBoundingBox(from maskCGImage: CGImage) -> CGRect? {
        guard let dataProvider = maskCGImage.dataProvider else {
            print("Failed to get data provider from mask image.")
            return nil
        }
        
        guard let pixelData = dataProvider.data else {
            print("Failed to get pixel data from data provider.")
            return nil
        }
        
        let data = CFDataGetBytePtr(pixelData)
        let bytesPerRow = maskCGImage.bytesPerRow
        let width = maskCGImage.width
        let height = maskCGImage.height
        let bitsPerPixel = maskCGImage.bitsPerPixel
        let bytesPerPixel = bitsPerPixel / 8
        
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundNonZeroPixel = false
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                let alpha = data?[pixelIndex + 3] ?? 0 // Assuming RGBA format
                if alpha > 0 { // Adjust based on your mask's pixel format
                    foundNonZeroPixel = true
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }
        
        if !foundNonZeroPixel {
            print("No object pixels found in mask image.")
            return nil
        }
        
        let bbox = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return bbox
    }
}

func generateYOLOAnnotations(
    segmentations: [SAMSegmentation],
    classMapping: [String: Int]
) -> String {
    var yoloAnnotations = ""
    
    for segmentation in segmentations {
        let classLabel = segmentation.title
        guard
              let classID = classMapping[classLabel] else {
            print("Unknown class label: \(segmentation.title)")
            continue
        }
        
        guard let path = segmentation.getTransformedCGPath() else {
            print("Failed to get transformed CGPath from segmentation \(segmentation.title)")
            continue
        }
        
        // Append annotation line
        let annotationLine = "\(classID) \(path.boundingBox.midX) \(path.boundingBox.midY) \(path.boundingBox.width) \(path.boundingBox.height)"
        yoloAnnotations += annotationLine + "\n"
    }
    
    return yoloAnnotations
}
//annotationLine    String    "843 0.5 0.5000000037252903 1.0 1.0000000074505806"
