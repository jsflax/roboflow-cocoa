//import Foundation
//import Roboflow
//import Vision
//import SwiftUI
//
//class SAMModel: ObservableObject {
//    let imageEncoderModel: MLModel
//    let promptEncoderModel: MLModel
//    let maskDecoderModel: MLModel
//    var image: CocoaImage
//    var depthImage: CocoaImage?
//    
//    var tapLocation: CGPoint? {
//        didSet {
//            if let tapLocation = tapLocation {
//                // Start the segmentation process
//                segmentObject(in: image, at: tapLocation) { [weak self] resultImage in
//                    DispatchQueue.main.async {
//                        if let resultImage = resultImage {
//                            self?.depthImage = resultImage
//                        } else {
//                            print("Failed to segment the object.")
//                        }
//                    }
//                }
//            }
//        }
//    }
//    
//    init(image: CocoaImage) {
//        self.image = image
//        // Load the Image Encoder model
//        self.imageEncoderModel = try! SAM2LargeMaskDecoderFLOAT16().model
////        guard let imageEncoderURL = Bundle.main.url(forResource: "SAM2LargeImageEncoderFLOAT16", withExtension: "mlpackage"),
////              let imageEncoderModel = try? MLModel(contentsOf: imageEncoderURL) else {
////            fatalError("Failed to load Image Encoder model")
////        }
////        self.imageEncoderModel = imageEncoderModel
////        
//        // Load the Prompt Encoder model
////        guard let promptEncoderURL = Bundle.main.url(forResource: "SAM2LargePromptEncoderFLOAT16", withExtension: "mlpackage"),
////              let promptEncoderModel = try? MLModel(contentsOf: promptEncoderURL) else {
////            fatalError("Failed to load Prompt Encoder model")
////        }
//        self.promptEncoderModel = try! SAM2LargePromptEncoderFLOAT16().model
//        
//        // Load the Mask Decoder model
////        guard let maskDecoderURL = Bundle.main.url(forResource: "SAM2LargeMaskDecoderFLOAT16", withExtension: "mlpackage"),
////              let maskDecoderModel = try? MLModel(contentsOf: maskDecoderURL) else {
////            fatalError("Failed to load Mask Decoder model")
////        }
//        self.maskDecoderModel = try! SAM2LargeMaskDecoderFLOAT16().model
//    }
//    
//    func segmentObject(in image: NSImage, at point: CGPoint, completion: @escaping (NSImage?) -> Void) {
//        DispatchQueue.global(qos: .userInitiated).async {
//            // Preprocess the image
//            guard let resizedImage = self.preprocessImage(image),
//                  let imageEmbedding = self.encodeImage(resizedImage),
//                  let promptEmbedding = self.encodePrompt(point: point, imageSize: image.size),
//                  let mask = self.decodeMask(imageEmbedding: imageEmbedding, promptEmbedding: promptEmbedding) else {
//                completion(nil)
//                return
//            }
//            
//            // Postprocess the mask and overlay it on the image
//            let resultImage = self.overlayMask(mask, on: image)
//            completion(resultImage)
//        }
//    }
//    
//    func preprocessImage(_ image: CocoaImage) -> CocoaImage? {
//        let targetSize = CGSize(width: 1024, height: 1024)
//        return image.resized(to: targetSize)
//    }
//    
//    
//    func encodeImage(_ image: NSImage) -> MLMultiArray? {
//        // Prepare the input for the Image Encoder
//        let imageConstraint = imageEncoderModel.modelDescription.inputDescriptionsByName["input_image"]!.imageConstraint
//        
//        // Convert NSImage to CVPixelBuffer
//        guard let pixelBuffer = image.pixelBuffer(width: imageConstraint!.pixelsWide, height: imageConstraint!.pixelsHigh) else {
//            return nil
//        }
//        
//        // Create the input
//        let input = SAM2LargeImageEncoderFLOAT16Input(image: pixelBuffer)
//        
//        // Get the prediction
//        guard let output = try? imageEncoderModel.prediction(from: input),
//              let imageEmbedding = output.featureValue(for: "image_embeddings")?.multiArrayValue else {
//            return nil
//        }
//        
//        return imageEmbedding
//    }
//    
//    func encodePrompt(point: CGPoint, imageSize: NSSize) -> MLMultiArray? {
//        // Normalize the point coordinates to [0,1]
//        let normalizedX = point.x / imageSize.width
//        let normalizedY = (imageSize.height - point.y) / imageSize.height // Flip y-axis
//        
//        // Create the point array
//        guard let pointArray = try? MLMultiArray(shape: [1, 2], dataType: .float32) else {
//            return nil
//        }
//        pointArray[0] = NSNumber(value: Float(normalizedX))
//        pointArray[1] = NSNumber(value: Float(normalizedY))
//        
//        // Create the label array (1 for foreground)
//        guard let labelArray = try? MLMultiArray(shape: [1], dataType: .int32) else {
//            return nil
//        }
//        labelArray[0] = NSNumber(value: 1)
//        
//        // Prepare the input for the Prompt Encoder
//        let input = SAM2LargePromptEncoderFLOAT16Input(points: pointArray, labels: labelArray)
//        
//        // Get the prediction
//        guard let output = try? promptEncoderModel.prediction(from: input),
//              let promptEmbedding = output.featureValue(for: "sparse_embeddings")?.multiArrayValue else {
//            return nil
//        }
//        
//        return promptEmbedding
//    }
//    
//    func decodeMask(imageEmbedding: MLMultiArray, promptEmbedding: MLMultiArray) -> MLMultiArray? {
//        // Initialize dense_embeddings as a zero array
//        guard let denseEmbeddings = try? MLMultiArray(shape: [1, 256, 64, 64], dataType: .float32) else {
//            return nil
//        }
//        denseEmbeddings.assignZero()
//        
//        // Initialize feats_s0 and feats_s1 as zero arrays
//        guard let feats_s0 = try? MLMultiArray(shape: [1, 256, 64, 64], dataType: .float32),
//              let feats_s1 = try? MLMultiArray(shape: [1, 256, 64, 64], dataType: .float32) else {
//            return nil
//        }
//        feats_s0.assignZero()
//        feats_s1.assignZero()
//        
//        // Prepare the input for the Mask Decoder
//        let input = SAM2LargeMaskDecoderFLOAT16Input(
//            image_embedding: imageEmbedding,
//            sparse_embedding: promptEmbedding,
//            dense_embedding: denseEmbeddings,
//            feats_s0: feats_s0,
//            feats_s1: feats_s1
//        )
//        
//        // Get the prediction
//        guard let output = try? maskDecoderModel.prediction(from: input),
//              let mask = output.featureValue(for: "mask")?.multiArrayValue else {
//            return nil
//        }
//        
//        return mask
//    }
//    
//    func overlayMask(_ maskArray: MLMultiArray, on image: NSImage) -> NSImage? {
//        // Convert MLMultiArray to NSImage
//        guard let maskImage = maskArray.toNSImage() else {
//            return nil
//        }
//        
//        // Resize the mask to match the original image size
//        guard let resizedMask = maskImage.resized(to: image.size) else {
//            return nil
//        }
//        
//        // Overlay the mask on the image
//        guard let finalImage = image.composited(with: resizedMask, alpha: 0.5) else {
//            return nil
//        }
//        
//        return finalImage
//    }
//}
//
//
//// Extensions
//
//extension NSImage {
//    func resized(to targetSize: NSSize) -> NSImage? {
//        let newImage = NSImage(size: targetSize)
//        newImage.lockFocus()
//        self.draw(in: NSRect(origin: .zero, size: targetSize),
//                  from: NSRect(origin: .zero, size: self.size),
//                  operation: .copy,
//                  fraction: 1.0)
//        newImage.unlockFocus()
//        return newImage
//    }
//    
//    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
//        var pixelBuffer: CVPixelBuffer?
//        let attributes: [NSObject: AnyObject] = [
//            kCVPixelBufferIOSurfacePropertiesKey: [:] as AnyObject
//        ]
//        let status = CVPixelBufferCreate(kCFAllocatorDefault,
//                                         width,
//                                         height,
//                                         kCVPixelFormatType_32BGRA,
//                                         attributes as CFDictionary,
//                                         &pixelBuffer)
//        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
//            return nil
//        }
//        
//        CVPixelBufferLockBaseAddress(buffer, .readOnly)
//        let context = CIContext()
//        if let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) {
//            let ciImage = CIImage(cgImage: cgImage)
//            context.render(ciImage, to: buffer)
//        } else {
//            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
//            return nil
//        }
//        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
//        return buffer
//    }
//    
//    func composited(with overlay: NSImage, alpha: CGFloat) -> NSImage? {
//        guard let baseCGImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil),
//              let overlayCGImage = overlay.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
//            return nil
//        }
//        
//        let size = self.size
//        let newImage = NSImage(size: size)
//        newImage.lockFocus()
//        
//        let context = NSGraphicsContext.current?.cgContext
//        context?.draw(baseCGImage, in: CGRect(origin: .zero, size: size))
//        
//        context?.setAlpha(alpha)
//        context?.draw(overlayCGImage, in: CGRect(origin: .zero, size: size))
//        
//        newImage.unlockFocus()
//        return newImage
//    }
//}
//
//extension MLMultiArray {
//    func toNSImage() -> NSImage? {
//        let height = self.shape[0].intValue
//        let width = self.shape[1].intValue
//        
//        guard let pointer = UnsafeMutablePointer<Float32>(OpaquePointer(self.dataPointer)) else {
//            return nil
//        }
//        
//        let count = width * height
//        var pixelData = [UInt8](repeating: 0, count: count)
//        
//        for i in 0..<count {
//            let value = pointer[i]
//            let pixelValue = UInt8(clamping: Int(value * 255))
//            pixelData[i] = pixelValue
//        }
//        
//        let colorSpace = CGColorSpaceCreateDeviceGray()
//        guard let dataProvider = CGDataProvider(data: Data(pixelData) as CFData) else {
//            return nil
//        }
//        
//        guard let cgImage = CGImage(width: width,
//                                    height: height,
//                                    bitsPerComponent: 8,
//                                    bitsPerPixel: 8,
//                                    bytesPerRow: width,
//                                    space: colorSpace,
//                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
//                                    provider: dataProvider,
//                                    decode: nil,
//                                    shouldInterpolate: false,
//                                    intent: .defaultIntent) else {
//            return nil
//        }
//        
//        let imageSize = NSSize(width: width, height: height)
//        return NSImage(cgImage: cgImage, size: imageSize)
//    }
//    
//    func assignZero() {
//        let pointer = UnsafeMutablePointer<Float32>(OpaquePointer(self.dataPointer))
//        let count = self.count
//        for i in 0..<count {
//            pointer[i] = 0.0
//        }
//    }
//}
