#if os(macOS)
import AppKit
#else
import UIKit
#endif
import VideoToolbox
import Roboflow

extension CocoaImage {
    /**
     Converts the image to an ARGB `CVPixelBuffer`.
     */
    public func pixelBuffer() -> CVPixelBuffer? {
        return pixelBuffer(width: Int(size.width), height: Int(size.height))
    }
    
    /**
     Resizes the image to `width` x `height` and converts it to an ARGB
     `CVPixelBuffer`.
     */
    public func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        return pixelBuffer(width: width, height: height,
                           pixelFormatType: kCVPixelFormatType_32ARGB,
                           colorSpace: CGColorSpaceCreateDeviceRGB(),
                           alphaInfo: .noneSkipFirst)
    }
    
    public func pixelBuffer(width: Int, height: Int,
                            pixelFormatType: OSType,
                            colorSpace: CGColorSpace,
                            alphaInfo: CGImageAlphaInfo) -> CVPixelBuffer? {
        var maybePixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferIOSurfacePropertiesKey: [:], // Allows flexible strides
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormatType,
            attrs,
            &maybePixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
            return nil
        }
        
        let flags = CVPixelBufferLockFlags(rawValue: 0)
        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
            return nil
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: alphaInfo.rawValue
        ) else {
            return nil
        }
        
        #if os(macOS)
        NSGraphicsContext.saveGraphicsState()
        let nscg = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nscg
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        #else
        // iOS code
        UIGraphicsPushContext(context)
        // Flip the context vertically to match UIKit's coordinate system
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        // Draw the image into the context
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        #endif
        return pixelBuffer
    }
    
//    /**
//     Resizes the image to `width` x `height` and converts it to a `CVPixelBuffer`
//     with the specified pixel format, color space, and alpha channel.
//     */
//    public func pixelBuffer(width: Int, height: Int,
//                            pixelFormatType: OSType,
//                            colorSpace: CGColorSpace,
//                            alphaInfo: CGImageAlphaInfo) -> CVPixelBuffer? {
//        var maybePixelBuffer: CVPixelBuffer?
//        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
//                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
//        let status = CVPixelBufferCreate(kCFAllocatorDefault,
//                                         width,
//                                         height,
//                                         pixelFormatType,
//                                         attrs as CFDictionary,
//                                         &maybePixelBuffer)
//        
//        guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
//            return nil
//        }
//        
//        let flags = CVPixelBufferLockFlags(rawValue: 0)
//        guard kCVReturnSuccess == CVPixelBufferLockBaseAddress(pixelBuffer, flags) else {
//            return nil
//        }
//        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, flags) }
//        
//        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
//                                      width: width,
//                                      height: height,
//                                      bitsPerComponent: 8,
//                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
//                                      space: colorSpace,
//                                      bitmapInfo: alphaInfo.rawValue)
//        else {
//            return nil
//        }
//        
//        #if os(macOS)
//        NSGraphicsContext.saveGraphicsState()
//        let nscg = NSGraphicsContext(cgContext: context, flipped: true)
//        NSGraphicsContext.current = nscg
//        context.translateBy(x: 0, y: CGFloat(height))
//        context.scaleBy(x: 1, y: -1)
//        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
//        NSGraphicsContext.restoreGraphicsState()
//        #else
//        // iOS code
//        UIGraphicsPushContext(context)
//        // Flip the context vertically to match UIKit's coordinate system
//        context.translateBy(x: 0, y: CGFloat(height))
//        context.scaleBy(x: 1.0, y: -1.0)
//        // Draw the image into the context
//        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
//        UIGraphicsPopContext()
//        #endif
//        return pixelBuffer
//    }
}
