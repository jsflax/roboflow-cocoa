//import CoreImage
//import Roboflow
//import CoreML
//import SwiftUI
//import os
//import Vision
//import LlavaKitShim
//import LlavaKit
//
//fileprivate let targetSize = CGSize(width: 448, height: 448)
//
//struct PathRoot {
//    let className: String
//    let rootPath: Path
//    let children: [Path]
//}
//
//final class DataModel: ObservableObject {
//    let context = CIContext()
//    
//    /// The depth model.
//    var model: DETRResnet50SemanticSegmentationF32?
//    var depthModel: DepthAnythingV2SmallF32?
//    var segmentationModel: VNCoreMLModel?
//    /// A pixel buffer used as input to the model.
//    let inputPixelBuffer: CVPixelBuffer
//    
//    /// The last image captured from the camera.
//    var lastImage = OSAllocatedUnfairLock<CIImage?>(uncheckedState: nil)
//    
//    /// The resulting depth image.
//    @Published var depthImage: CocoaImage?
//    @Published var depthPaths: [PathRoot] = []
//    var tapLocation: CGPoint? {
//        didSet {
//            if let tapLocation = tapLocation {
//                try? loadModel()
//                lastImage.withLock { image in
//                    generateSegmentationMask(for: image!.image!) { [weak self, image] (maskImage, multiArray) in
//                        if let multiArray = multiArray {
//                            // Isolate the clicked object
//                            self?.isolateTappedObject(multiArray: multiArray, clickLocation: tapLocation, originalImage: image!.image!)
//                        }
//                    }
//                }
//            }
//        }
//    }
//    func getLabelColor(at point: CGPoint, in maskImage: NSImage) -> NSColor? {
//        guard let bitmapRep = NSBitmapImageRep(data: maskImage.tiffRepresentation!) else {
//            return nil
//        }
//
//        let x = Int(point.x)
//        let y = Int(maskImage.size.height - point.y) // Flip y-coordinate for macOS
//
//        if x >= 0 && x < Int(maskImage.size.width) && y >= 0 && y < Int(maskImage.size.height) {
//            let color = bitmapRep.colorAt(x: x, y: y)
//            return color
//        }
//        return nil
//    }
//    
//    func createObjectMask(from multiArray: MLMultiArray, targetLabel: Int32) -> CGImage? {
//        let height = multiArray.shape[0].intValue
//        let width = multiArray.shape[1].intValue
//        let count = width * height
//
//        let pointer = multiArray.dataPointer.bindMemory(to: Int32.self, capacity: count)
//        // Create mask data
//        var maskData = [UInt8](repeating: 0, count: count)
//        for i in 0..<count {
//            maskData[i] = (pointer[i] == targetLabel) ? 255 : 0
//        }
//
//        guard let dataProvider = CGDataProvider(data: Data(maskData) as CFData) else {
//            return nil
//        }
//
//        // Create mask image
//        return CGImage(
//            width: width,
//            height: height,
//            bitsPerComponent: 8,
//            bitsPerPixel: 8,
//            bytesPerRow: width,
//            space: CGColorSpaceCreateDeviceGray(),
//            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
//            provider: dataProvider,
//            decode: nil,
//            shouldInterpolate: false,
//            intent: .defaultIntent
//        )
//    }
//    func getLabelAtPoint(_ point: CGPoint, in multiArray: MLMultiArray, imageSize: CGSize) -> Int32? {
//        let height = multiArray.shape[0].intValue
//        let width = multiArray.shape[1].intValue
//
//        // Convert the point to the coordinate space of the multiArray
//        let scaleX = CGFloat(width) / imageSize.width
//        let scaleY = CGFloat(height) / imageSize.height
//
//        let x = Int(point.x * scaleX)
//        let y = Int((imageSize.height - point.y) * scaleY) // Flip y-coordinate
//
//        if x >= 0 && x < width && y >= 0 && y < height {
//            let index = y * width + x
//            let pointer = UnsafeMutablePointer<Int32>(OpaquePointer(multiArray.dataPointer))
//            return pointer[index]
//        }
//        return nil
//    }
//    func isolateTappedObject(multiArray: MLMultiArray, clickLocation: CGPoint, originalImage: NSImage) {
//        guard let originalCGImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
//            return
//        }
//
//        // Get the class label at the clicked location
//        let imageSize = originalImage.size
//        guard let label = getLabelAtPoint(clickLocation, in: multiArray, imageSize: imageSize) else {
//            return
//        }
//
//        // Create a mask for the clicked object
//        if let objectMask = createObjectMask(from: multiArray, targetLabel: label) {
//            // Apply the mask to the original image
//            if let finalImage = applyMask(objectMask, to: originalCGImage) {
//                DispatchQueue.main.async { [self] in
//                    self.saveImageAsJPEG(image: finalImage, path: fm.temporaryDirectory.appending(path: "tmp.jpg").path())
//                    self.depthImage = finalImage
//                }
//            }
//        }
//    }
//    let fm = FileManager.default
//    func pixelBufferToNSImage(pixelBuffer: CVPixelBuffer) -> NSImage? {
//        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//        let context = CIContext(options: nil)
//        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
//            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
//        }
//        return nil
//    }
//    
//    func createMask(from image: CGImage) -> CGImage? {
//        guard let dataProvider = image.dataProvider else { return nil }
//
//        return CGImage(
//            width: image.width,
//            height: image.height,
//            bitsPerComponent: 8,
//            bitsPerPixel: 8,
//            bytesPerRow: image.width,
//            space: CGColorSpaceCreateDeviceGray(),
//            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
//            provider: dataProvider,
//            decode: nil,
//            shouldInterpolate: false,
//            intent: .defaultIntent
//        )
//    }
//    func applyMask(_ mask: CGImage, to imageCG: CGImage) -> NSImage? {
//        let imageWidth = imageCG.width
//        let imageHeight = imageCG.height
//        let size = NSSize(width: imageWidth, height: imageHeight)
//
//        // Resize the mask if needed
//        let maskWidth = mask.width
//        let maskHeight = mask.height
//
//        let resizedMask = (maskWidth != imageWidth || maskHeight != imageHeight) ? resizeCGImage(mask, to: size) : mask
//
//        // Create the proper mask for clipping
//        guard let maskRef = createMask(from: resizedMask!) else {
//            return nil
//        }
//
//        // Create a new context
//        guard let context = CGContext(
//            data: nil,
//            width: imageWidth,
//            height: imageHeight,
//            bitsPerComponent: imageCG.bitsPerComponent,
//            bytesPerRow: 0,
//            space: imageCG.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
//            bitmapInfo: imageCG.bitmapInfo.rawValue
//        ) else {
//            return nil
//        }
//
//        // Clip to the mask
//        context.clip(to: CGRect(origin: .zero, size: size), mask: maskRef)
//
//        // Draw the original image
//        context.draw(imageCG, in: CGRect(origin: .zero, size: size))
//
//        // Get the masked image
//        guard let maskedCGImage = context.makeImage() else {
//            return nil
//        }
//
//        return NSImage(cgImage: maskedCGImage, size: size)
//    }
//    func resizeCGImage(_ image: CGImage, to size: NSSize) -> CGImage? {
//        guard let colorSpace = image.colorSpace else {
//            return nil
//        }
//
//        guard let context = CGContext(
//            data: nil,
//            width: Int(size.width),
//            height: Int(size.height),
//            bitsPerComponent: image.bitsPerComponent,
//            bytesPerRow: 0,
//            space: colorSpace,
//            bitmapInfo: image.bitmapInfo.rawValue
//        ) else {
//            return nil
//        }
//
//        context.interpolationQuality = .none
//        context.draw(image, in: CGRect(origin: .zero, size: size))
//        return context.makeImage()
//    }
//    func multiArrayToNSImage(multiArray: MLMultiArray) -> NSImage? {
//        let height = multiArray.shape[0].intValue
//        let width = multiArray.shape[1].intValue
//
//        // Flatten the MLMultiArray to get the label data
//        let pointer = UnsafeMutablePointer<Int32>(OpaquePointer(multiArray.dataPointer))
//        let count = multiArray.count
//        let buffer = UnsafeBufferPointer(start: pointer, count: count)
//        let labels = Array(buffer)
//
//        // Create a grayscale CGImage from the label data
//        let colorSpace = CGColorSpaceCreateDeviceGray()
//        guard let context = CGContext(
//            data: nil,
//            width: width,
//            height: height,
//            bitsPerComponent: 8,
//            bytesPerRow: width,
//            space: colorSpace,
//            bitmapInfo: CGImageAlphaInfo.none.rawValue
//        ) else {
//            return nil
//        }
//
//        // Normalize label data to fit in 0-255 range
//        let maxLabel = labels.max() ?? 1
//        let scaledLabels = labels.map { UInt8($0 * 255 / maxLabel) }
//
//        context.data?.copyMemory(from: scaledLabels, byteCount: scaledLabels.count)
//
//        guard let cgImage = context.makeImage() else {
//            return nil
//        }
//
//        // Convert CGImage to NSImage
//        let maskImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
//        return maskImage
//    }
//    func generateSegmentationMask(for image: NSImage, completion: @escaping (NSImage?, MLMultiArray?) -> Void) {
//        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
//              let model = segmentationModel else {
//            completion(nil, nil)
//            return
//        }
//
//        let request = VNCoreMLRequest(model: model) { request, error in
//            if let results = request.results as? [VNCoreMLFeatureValueObservation],
//               let multiArray = results.first?.featureValue.multiArrayValue {
//                // Convert MLMultiArray to NSImage
//                let maskImage = self.multiArrayToNSImage(multiArray: multiArray)
//                completion(maskImage, multiArray)
//            } else {
//                completion(nil, nil)
//            }
//        }
//
//        request.imageCropAndScaleOption = .scaleFill
//
//        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
//
//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                try handler.perform([request])
//            } catch {
//                print("Error performing segmentation request: \(error)")
//                completion(nil, nil)
//            }
//        }
//    }
//    
//    let labels: [String]
//    
//    init(labels: [String]) {
//        // Create a reusable buffer to avoid allocating memory for every model invocation
//        var buffer: CVPixelBuffer!
//        let status = CVPixelBufferCreate(
//            kCFAllocatorDefault,
//            Int(targetSize.width),
//            Int(targetSize.height),
//            kCVPixelFormatType_32ARGB,
//            nil,
//            &buffer
//        )
//        guard status == kCVReturnSuccess else {
//            fatalError("Failed to create pixel buffer")
//        }
//        inputPixelBuffer = buffer
//        self.labels = labels
//    }
//    //
//    //    func handleCameraFeed() async {
//    //        let imageStream = camera.previewStream
//    //        for await image in imageStream {
//    //            lastImage.withLock({ $0 = image })
//    //        }
//    //    }
//    
//    func runModel() async {
//        try! loadModel()
//        
//        let clock = ContinuousClock()
//        var durations = [ContinuousClock.Duration]()
//        
//        
//        //        while !Task.isCancelled {
//        print("Locking image")
//        let image = lastImage.withLock({ $0 })
//        try! await performInference(image!.cgImage!)
//    }
//    /// The sementation post-processor.
//    var postProcessor: DETRPostProcessor?
//    
//    func loadModel() throws {
//        print("Loading model...")
//        
//        let clock = ContinuousClock()
//        let start = clock.now
//        
//        model = try DETRResnet50SemanticSegmentationF32()
//        depthModel = try DepthAnythingV2SmallF32()
//        if let model = model {
//            postProcessor = try DETRPostProcessor(model: model.model)
//        }
//        if let mlModel = try? DeepLabV3(configuration: MLModelConfiguration()).model {
//            segmentationModel = try? VNCoreMLModel(for: mlModel)
//        }
//        let duration = clock.now - start
//        print("Model loaded (took \(duration.formatted(.units(allowed: [.seconds, .milliseconds]))))")
//    }
//    
//    func scalePath(_ path: CGPath, to size: CGSize) -> CGPath? {
//        var transform = CGAffineTransform.identity
//        
//        // Scale the path to the image size
//        transform = transform.scaledBy(x: size.width, y: size.height)
//        
//        // Flip the Y-axis
//        transform = transform.scaledBy(x: 1.0, y: -1.0)
//        
//        // Translate the path back into the image's coordinate space
//        transform = transform.translatedBy(x: 0, y: -1.0)
//        
//        return path.copy(using: &transform)
//    }
//    enum InferenceError: Error {
//        case postProcessing
//        case computingBoundingBox
//    }
//    
//    func performInference(_ image: CGImage) async throws {
//        guard let model, let depthModel else {
//            return
//        }
//        
//        let originalSize = CGSize(width: image.width,
//                                  height: image.height)
//        let originalCIImage = CIImage(cgImage: image)
//            
//        
//        // Step 1: Apply contrast enhancement to the image
//        let contrastEnhancedImage = enhanceContrast(of: originalCIImage, contrast: 1.5)
//        let inputImage = contrastEnhancedImage
//            .resized(to: targetSize)
//        context.render(inputImage, to: inputPixelBuffer)
//        let depthResult = try depthModel.prediction(image: inputPixelBuffer)
//        depthImage = CocoaImage(pixelBuffer: depthResult.depth)
//        let result = try model.prediction(image: inputPixelBuffer)
//        guard let semanticImage = try? postProcessor?.semanticImage(semanticPredictions: result.semanticPredictionsShapedArray) else {
//            throw InferenceError.postProcessing
//        }
//        
//        try await processSemanticPredictions(result.semanticPredictionsShapedArray,
//                                             originalImage: inputImage.cgImage!,
//                                             classNames: postProcessor!.ids2Labels)
//        let outputImage = semanticImage.resized(to: originalSize)
//        await Task { @MainActor in
//            self.depthImage = outputImage.image!
//        }.value
//    }
//    
//    private func computeBoundingBox(maskCGImage: CGImage) async throws -> CGRect {
//        let request = VNDetectContoursRequest()
//        request.contrastAdjustment = 1.0
//        request.detectsDarkOnLight = false
//        request.maximumImageDimension = 512
//        
//        let handler = VNImageRequestHandler(cgImage: maskCGImage, options: [:])
//        return try await withCheckedThrowingContinuation { continuation in
//            DispatchQueue.global(qos: .userInitiated).async {
//                do {
//                    try handler.perform([request])
//                    if let observation = request.results?.first as? VNContoursObservation {
//                        var combinedBoundingBox: CGRect?
//                        for contour in observation.topLevelContours {
//                            let path = contour.normalizedPath
//                            let boundingBox = path.boundingBox
//                            if let currentBox = combinedBoundingBox {
//                                combinedBoundingBox = currentBox.union(boundingBox)
//                            } else {
//                                combinedBoundingBox = boundingBox
//                            }
//                        }
//                        if let boundingBox = combinedBoundingBox {
//                            let imageSize = CGSize(width: maskCGImage.width, height: maskCGImage.height)
//                            let transformedBox = VNImageRectForNormalizedRect(boundingBox, Int(imageSize.width), Int(imageSize.height))
//                            DispatchQueue.main.async {
//                                continuation.resume(returning: transformedBox)
//                            }
//                        } else {
//                            DispatchQueue.main.async {
//                                continuation.resume(throwing: InferenceError.computingBoundingBox)
//                            }
//                        }
//                    } else {
//                        DispatchQueue.main.async {
//                            continuation.resume(throwing: InferenceError.computingBoundingBox)
//                        }
//                    }
//                } catch {
//                    print("Failed to perform contours request: \(error.localizedDescription)")
//                    DispatchQueue.main.async {
//                        continuation.resume(throwing: InferenceError.computingBoundingBox)
//                    }
//                }
//            }
//        }
//    }
//    
//    private func drawBoundingBox(on image: CIImage, boundingBox: CGRect) -> CIImage? {
//        let size = image.extent.size
//        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
//        
//        // Corrected line: Directly using the colorSpace
//        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
//            return nil
//        }
//        
//        guard let context = CGContext(data: nil,
//                                      width: Int(size.width),
//                                      height: Int(size.height),
//                                      bitsPerComponent: 8,
//                                      bytesPerRow: 0,
//                                      space: colorSpace,
//                                      bitmapInfo: bitmapInfo) else {
//            return nil
//        }
//        
//        let ciContext = CIContext(cgContext: context, options: nil)
//        ciContext.draw(image, in: image.extent, from: image.extent)
//        
//        context.setStrokeColor(CocoaColor.red.cgColor)
//        context.setLineWidth(5.0)
//        
//        context.stroke(boundingBox)
//        
//        guard let cgImage = context.makeImage() else {
//            return nil
//        }
//        let resultImage = CIImage(cgImage: cgImage)
//        return resultImage
//    }
//    
//    private func highlightMaskedRegions(originalImage: CIImage, maskImage: CIImage) -> CIImage? {
//        // Desaturate the original image
//        let desaturatedImage = originalImage.applyingFilter("CIColorControls", parameters: [
//            kCIInputSaturationKey: 0.0
//        ])
//        
//        // Combine the desaturated image with the original image using the mask
//        let highlightedImage = originalImage.applyingFilter("CIBlendWithMask", parameters: [
//            "inputBackgroundImage": desaturatedImage,
//            "inputMaskImage": maskImage
//        ])
//        
//        return highlightedImage
//    }
//    
//    //    private func performInference(_ pixelBuffer: CVPixelBuffer) async throws {
//    //        guard let model else {
//    //            return
//    //        }
//    //
//    //        let originalSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
//    //                                  height: CVPixelBufferGetHeight(pixelBuffer))
//    //        let inputImage = CIImage(cvPixelBuffer: pixelBuffer)
//    //            .resized(to: targetSize)
//    //        context.render(inputImage, to: inputPixelBuffer)
//    //        let result = try model.prediction(image: inputPixelBuffer)
//    //
//    //        guard let semanticImage = try? postProcessor?.semanticImage(semanticPredictions: result.semanticPredictionsShapedArray) else {
//    //            throw InferenceError.postProcessing
//    //        }
//    //        let outputImage = semanticImage.resized(to: originalSize)
//    //        detectContours(in: outputImage) { observation in
//    //            if let observation = observation {
//    //                func iterateContours(contours: [VNContour]) {
//    //                    for contour in contours {
//    //                        // Each contour is a VNContour
//    //                        let path = contour.normalizedPath
//    //                        guard let scaledPath = self.scalePath(path, to: outputImage.extent.size) else {
//    //                            continue
//    //                        }
//    //                        DispatchQueue.main.async {
//    ////                            self.depthPaths.append((Path(scaledPath))
//    //                        }
//    //                        print("Child contour count: \(contour.childContourCount)")
//    //                        // Scale and use the path
//    //                        iterateContours(contours: contour.childContours)
//    //                    }
//    //                }
//    //                iterateContours(contours: observation.topLevelContours)
//    //                // Use the path, for example, overlay it on the original image
//    //            } else {
//    //                print("Failed to detect contours.")
//    //            }
//    //        }
//    //        Task { @MainActor in
//    //            depthImage = outputImage.image
//    //        }
//    //    }
//    
//    func detectContours(in ciImage: CIImage, completion: @escaping (VNContoursObservation?) -> Void) {
//        let contoursRequest = VNDetectContoursRequest()
//        contoursRequest.contrastAdjustment = 3
//        contoursRequest.detectsDarkOnLight = true
//        contoursRequest.maximumImageDimension = Int(ciImage.image!.size.width)
//        //        contoursRequest.contrastPivot = 2
//        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                try handler.perform([contoursRequest])
//                if let observation = contoursRequest.results?.first as? VNContoursObservation {
//                    completion(observation)
//                } else {
//                    print("No contours detected.")
//                    completion(nil)
//                }
//            } catch {
//                print("Failed to perform contours request: \(error.localizedDescription)")
//                completion(nil)
//            }
//        }
//    }
//    
//    func createBinaryMask(forClass classLabel: Int32, from predictions: MLShapedArray<Int32>) -> CGImage? {
//        let height = predictions.shape[0]
//        let width = predictions.shape[1]
//        let dataCount = height * width
//        
//        // Flatten the predictions
//        let flattenedPredictions: [Int32]
//        flattenedPredictions = Array(predictions.scalars)
//        
//        // Create pixel data for the mask
//        var pixelData = [UInt8](repeating: 0, count: dataCount)
//        for i in 0..<dataCount {
//            pixelData[i] = (flattenedPredictions[i] == classLabel) ? 255 : 0
//        }
//        
//        // Create a grayscale image from the pixel data
//        let colorSpace = CGColorSpaceCreateDeviceGray()
//        let bytesPerRow = width
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
//        
//        guard let providerRef = CGDataProvider(data: Data(pixelData) as CFData) else {
//            return nil
//        }
//        
//        let cgImage = CGImage(width: width,
//                              height: height,
//                              bitsPerComponent: 8,
//                              bitsPerPixel: 8,
//                              bytesPerRow: bytesPerRow,
//                              space: colorSpace,
//                              bitmapInfo: bitmapInfo,
//                              provider: providerRef,
//                              decode: nil,
//                              shouldInterpolate: false,
//                              intent: .defaultIntent)
//        
//        return cgImage
//    }
//    func enhanceContrast(of image: CIImage, contrast: Float = 1.5) -> CIImage {
//        return image.applyingFilter("CIColorControls", parameters: [
//            kCIInputContrastKey: contrast // Adjust contrast (1.0 is default, > 1.0 increases contrast)
//        ])
//    }
//    func convertContoursToPaths(observation: VNContoursObservation, imageSize: CGSize) -> [CGPath] {
//        var paths: [CGPath] = []
//        var transform = CGAffineTransform(scaleX: imageSize.width, y: imageSize.height)
//        transform = transform.scaledBy(x: 1.0, y: -1.0)
//        transform = transform.translatedBy(x: 0, y: -1.0)
//        
//        func iterateContours(contours: [VNContour]) {
//            for contour in contours {
//                // Each contour is a VNContour
//                if let path = contour.normalizedPath.copy(using: &transform) {
//                    
//                    paths.append(path)
//                }
//                print("COUNTOUR COUNT:", contour.childContourCount)
//                // Scale and use the path
//                iterateContours(contours: contour.childContours)
//            }
//        }
//        iterateContours(contours: observation.topLevelContours)
//        return paths
//    }
//    
//    #if os(macOS)
//    func saveImageAsJPEG(image: CocoaImage, path: String, compressionQuality: CGFloat = 0.9) -> Bool {
//        guard let tiffData = image.tiffRepresentation,
//              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
//            print("Failed to get TIFF representation or BitmapImageRep.")
//            return false
//        }
//        
//        // Convert the image to JPEG data
//        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
//            print("Failed to convert image to JPEG.")
//            return false
//        }
//        
//        // Write the JPEG data to the specified path
//        return FileManager.default.createFile(atPath: path, contents: jpegData, attributes: nil)
//    }
//    #else
//    func saveImageAsJPEG(image: UIImage, path: String, compressionQuality: CGFloat = 0.9) -> Bool {
//        // Convert UIImage to JPEG data with the specified compression quality
//        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
//            print("Failed to convert image to JPEG.")
//            return false
//        }
//        
//        // Write the JPEG data to the specified path
//        do {
//            try jpegData.write(to: URL(fileURLWithPath: path))
//            return true
//        } catch {
//            print("Failed to save image to path: \(error.localizedDescription)")
//            return false
//        }
//    }
//    #endif
//    
//    private func processSemanticPredictions(_ predictions: MLShapedArray<Int32>,
//                                            originalImage: CGImage,
//                                            classNames: [Int: String]) async throws {
//        let height = predictions.shape[0]
//        let width = predictions.shape[1]
//        let imageSize = CGSize(width: width, height: height)
//        
//        // Flatten the predictions
//        let flattenedPredictions: [Int32]
//        flattenedPredictions = Array(predictions.scalars)
//        
//        let classLabels = Set(flattenedPredictions)
//        print(classLabels)
//        for classLabel in classLabels {
//            print(classNames[Int(classLabel)])
//            // Skip background class if necessary
//            if classLabel == 0 {
//                continue
//            }
//            
//            guard let maskImage = createBinaryMask(forClass: classLabel,
//                                                   from: predictions) else {
//                print("NO MASK IMAGE")
//                continue
//            }
//            let highlightedImage = highlightMaskedRegions(originalImage: CIImage(cgImage: originalImage), maskImage: CIImage(cgImage: maskImage))
//            let fm = FileManager.default
////            guard fm.createFile(atPath: fm.temporaryDirectory.appending(path: "segmented_img_\(classLabel).jpg").path(), contents: CocoaImage(cgImage: maskImage, size: .init(width: width, height: height)).tiffRepresentation!) else {
////                fatalError()
////            }
//            saveImageAsJPEG(image: CocoaImage(cgImage: maskImage, size: .init(width: maskImage.width,
//                                                                              height: maskImage.height)), path: fm.temporaryDirectory.appending(path: "segmented_img_\(classLabel).jpg").path())
//            saveImageAsJPEG(image: highlightedImage!.image!, path: fm.temporaryDirectory.appending(path: "segmented_img_\(classLabel)_highlighted.jpg").path())
//            //            guard fm.createFile(atPath: fm.temporaryDirectory.appending(path: "segmented_img_\(classLabel)_highlighted.jpg").path(),
//            //                                contents: highlightedImage!.image!.tiffRepresentation!) else {
//            //                fatalError()
//            //            }
//            let boundingBox = try await computeBoundingBox(maskCGImage: maskImage)
//            let boxedAndHighlightedImage = drawBoundingBox(on: highlightedImage!, boundingBox: boundingBox)
//            saveImageAsJPEG(image: boxedAndHighlightedImage!.image!, path: fm.temporaryDirectory.appending(path: "segmented_img_\(classLabel)_boxed_highlighted.jpg").path())
//            let className = classNames[Int(classLabel)] ?? "Unknown"
//            
//            let prediction = try llavaPrediction(imagePath: fm.temporaryDirectory.appending(path: "segmented_img_\(classLabel)_boxed_highlighted.jpg").path(),
//                                                 labels: labels,
//                                                 hint: className)
//            guard prediction.confidenceScore >= 0.85 else {
//                continue
//            }
//            print("PREDICTION: \(prediction)")
//            detectContours(in: CIImage(cgImage: maskImage)) { observation in
//                guard let observation = observation else {
//                    print("No contours detected for class \(classLabel).")
//                    return
//                }
//
//                let paths = self.lastImage.withLock {
//                    self.convertContoursToPaths(observation: observation, imageSize: $0!.extent.size)
//                }
//                let rootPath = PathRoot(className: prediction.classLabel, rootPath: Path(paths[0]), children: paths[1..<paths.count].map(Path.init))
//                print("PATH COUNT: \(paths.count)")
//                // Use the paths and classLabel as needed
//                Task { @MainActor in
//                    self.depthPaths.append(rootPath)
//                }
//            }
//        }
//    }
//}
////
////extension CIImage {
////    /// Returns a resized image.
////    func resized(to size: CGSize) -> CIImage {
////        let outputScaleX = size.width / extent.width
////        let outputScaleY = size.height / extent.height
////        var outputImage = self.transformed(by: CGAffineTransform(scaleX: outputScaleX, y: outputScaleY))
////        outputImage = outputImage.transformed(
////            by: CGAffineTransform(translationX: -outputImage.extent.origin.x, y: -outputImage.extent.origin.y)
////        )
////        return outputImage
////    }
////}
//
#if os(iOS)
extension UIImage {
    convenience init(cgImage: CGImage, size: CGSize) {
        self.init(cgImage: cgImage)
    }
}
#endif
import Roboflow
#if os(macOS)
import AppKit
#else
import UIKit
#endif

fileprivate extension CIImage {
    var image: CocoaImage? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        #if os(macOS)
        return CocoaImage(cgImage: cgImage, size: .init(width: cgImage.width, height: cgImage.height))
        #else
        return CocoaImage(cgImage: cgImage)
        #endif
    }
    
    var cgImage: CGImage? {
        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
        return cgImage
    }
    
    func createPixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.extent.width)
        let height = Int(self.extent.height)
        let pixelFormat = kCVPixelFormatType_32BGRA
        
        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         pixelFormat,
                                         attributes as CFDictionary,
                                         &pixelBuffer)
        if status != kCVReturnSuccess {
            print("Failed to create pixel buffer")
            return nil
        }
        return pixelBuffer
    }
}
import SwiftUI
extension Image {
    init(cocoaImage: CocoaImage) {
        #if os(macOS)
        self.init(nsImage: cocoaImage)
        #else
        self.init(uiImage: cocoaImage)
        #endif
    }
}
