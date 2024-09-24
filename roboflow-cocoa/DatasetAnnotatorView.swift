//import Foundation
//import Roboflow
//import SwiftUI
//import Vision
//import simd
//import CoreML
//import Vision
//
//
//struct AnnotationCanvas: View {
//    let image: Project.ImageMetadata
//    @State var cocoaImage: CocoaImage
//    @State private var totalZoom = 1.0
//    @State private var offset = CGSize.zero
//    @State private var currentZoom = -0.8
//    @Binding var toggleLabels: Bool
//    @Binding var toggleSegmentation: Bool
//    @State private var model: VNCoreMLModel?
////    @ObservedObject var dataModel: DataModel
////    @ObservedObject var samModel: SAMModel
//    
//    var body: some View {
//        Canvas { ctx, size in
//            let img = ctx.resolve(Image(cocoaImage: cocoaImage))
//            let origin = ctx.clipBoundingRect.origin
//            let imgRect = CGRect(x: origin.x, y: origin.y, width: image.annotation?.width ?? img.size.width,
//                                 height: image.annotation?.height ?? img.size.height)
//            print("IMAGE SIZE:", img.size)
//            ctx.draw(img, in: imgRect)
//            if let image = samModel.depthImage {
//                let img = ctx.resolve(Image(cocoaImage: image))
//                ctx.opacity = 0.5
//                ctx.draw(img, in: imgRect)
//                ctx.opacity = 1
//            }
//            if toggleSegmentation {
//
//                for path in dataModel.depthPaths {
//                    ctx.stroke(Path(path.rootPath.boundingRect), with: .color(.yellow), style: .init(lineWidth: 20))
//                    ctx.stroke(path.rootPath, with: .color(.yellow), style: .init(lineWidth: 20))
//                    for child in path.children {
////                        ctx.stroke(child, with: .color(.blue), style: .init(lineWidth: 20))
//                        ctx.stroke(Path(child.boundingRect), with: .color(.blue), style: .init(lineWidth: 20))
//                        let textRect = CGRect(x: child.boundingRect.minX, y: child.boundingRect.minY, width: 100, height: 100)
//                        ctx.draw(ctx.resolve(Text(path.className).font(.system(size: 50))), in: textRect)
//                    }
//
//                }
//            }
//            if toggleLabels, let annotation = image.annotation {
//                for box in annotation.boxes {
//                    if let points = box.points {
//                        print("points")
//                        var path = Path()
//                        path.move(to: points[0])
//                        path.addLines(points)
//                        path.closeSubpath()
//                        ctx.stroke(path, with: .color(.green), style: .init(lineWidth: 5))
//                    } else {
//                        print("Drawing polygon")
//                        var path = Path()
//                        
//                        let boxRect = CGRect(x: NSDecimalNumber(decimal: box.x).doubleValue,
//                                             y:  NSDecimalNumber(decimal: box.y).doubleValue, width: NSDecimalNumber(decimal: box.width).doubleValue, height: NSDecimalNumber(decimal: box.height).doubleValue)
//                        
//                        let normalized = CGRect(x: boxRect.minX - boxRect.width/2, y: boxRect.minY - boxRect.height/2, width: boxRect.width, height: boxRect.height)
//                        path.addRect(normalized)
//                        path.closeSubpath()
//                        
//                        ctx.stroke(Path(normalized), with: .color(.green), style: .init(lineWidth: 5))
//                    }
//                }
//            }
//        }
//        .scaleEffect(currentZoom + totalZoom)
//        .offset(offset)
//        .onTapGesture { location in
//                print("Tapped at \(location)")
//            samModel.tapLocation = location
//          }
//        .gesture(
//            MagnifyGesture()
//                .onChanged { value in
//                    currentZoom = value.magnification - 1
//                }
//                .onEnded { value in
//                    totalZoom += currentZoom
//                    currentZoom = 0
//                }
//                .simultaneously(with: DragGesture()
//                    .onChanged { gesture in
//                        offset = gesture.translation
//                    }
//                    .onEnded { _ in
//                        if abs(offset.width) > 100 {
//                            // remove the card
//                        } else {
//                            //                                            offset = .zero
//                        }
//                    })
//        )
//        .accessibilityZoomAction { action in
//            if action.direction == .zoomIn {
//                totalZoom += 1
//            } else {
//                totalZoom -= 1
//            }
//        }
//        .frame(width: image.annotation?.width ?? cocoaImage.size.width, height: image.annotation?.height ?? cocoaImage.size.height)
//        .task {
//            
//        }.onAppear {
//            dataModel.lastImage.withLock { img in
//                img = self.cocoaImage.ciImage()
//            }
//        }
//        .onChange(of: toggleSegmentation, {
//            if toggleSegmentation {
//                Task {
//                    dataModel.lastImage.withLock { img in
//                        img = self.cocoaImage.ciImage()
//                    }
//                    //                try! dataModel.loadModel()
//                    await dataModel.runModel()
//                }
//            }
////            let request = VNCoreMLRequest(model: model!) { request, error in
////                print("RECEIVING REQUEST: Error \(error) Request: \(request.results)")
////                if let results = request.results as? [VNPixelBufferObservation],
////                   let pixelBuffer = results.first?.pixelBuffer,
////                   let depthMapImage = createImageFromFloat16PixelBuffer(pixelBuffer) {
////                    DispatchQueue.main.async {
////                        // Display the depth map image
////                        cocoaImage = depthMapImage
////                    }
////                } else {
////                    print("Failed to process depth estimation.")
////                }
////            }
////            request.imageCropAndScaleOption = .scaleFill
////            guard let tiffData = cocoaImage.tiffRepresentation,
////                  let bitmap = NSBitmapImageRep(data: tiffData) else { return }
////            let ciImage = CIImage(bitmapImageRep: bitmap)
////            let handler = VNImageRequestHandler(ciImage: ciImage!)
////            DispatchQueue.global(qos: .userInitiated).async {
////                do {
////                    try handler.perform([request])
////                } catch {
////                    print("Failed to perform image segmentation: \(error.localizedDescription)")
////                }
////            }
//        })
//    }
//}
//
//struct DatasetAnnotatorView: View {
//    @State var image: Project.ImageMetadata?
//    let labels: [String]
//    @State var imageBG: Data?
//    @State var toggleLabels: Bool = true
//    @State var toggleSegmentation: Bool = false
//    private let imageCompact: RFImageCompact
//    init(image: RFImageCompact, labels: [String]) {
//        self.labels = labels
//        self.imageCompact = image
//    }
//    
//    var body: some View {
//        GeometryReader { geo in
//            if let imageBG = imageBG, let cocoaImg = CocoaImage(data: imageBG), let image = image {
//                ZStack {
//                    AnnotationCanvas(image: image, cocoaImage: cocoaImg, toggleLabels: $toggleLabels, toggleSegmentation: $toggleSegmentation, dataModel: DataModel(labels: labels), samModel: SAMModel(image: cocoaImg))
//                    HStack {
//                        Spacer()
//                        VStack {
//                            Button("", systemImage: "arrow.up.and.down.and.arrow.left.and.right") {
//                            }
//                            Button("", systemImage: "togglepower") {
//                                toggleLabels.toggle()
//                            }
//                            Button("", systemImage: "bolt") {
//                                toggleSegmentation.toggle()
//                            }
//                        }
//                    }.frame(width: geo.size.width, height: geo.size.height)
//                    //                }
//                }.frame(width: geo.size.width, height: geo.size.height)
//            } else {
//                ProgressView()
//            }
//        }.task {
//            do {
//                let details = try await self.imageCompact.details
//                self.image = details
//                imageBG = try await URLSession.shared.data(from: URL(string: details.urls.original.replacingOccurrences(of: "undefined", with: self.imageCompact.id))!).0
//            } catch {
//                print(error)
//            }
//        }
//    }
//}
//
//#Preview {
//    @Previewable @State var image: RFImageCompact?
////    let image = try! JSONDecoder().decode(Project.ImageMetadata.self, from: String(contentsOfFile:  Bundle.main.path(forResource: "annotation_test0", ofType: "json")!).data(using: .utf8)!)
//    NavigationSplitView {
//        EmptyView()
//    } detail: {
//        VStack {
//            if let image = image {
//                DatasetAnnotatorView(image: image, labels: ["orange", "orange juice"])
//            }
//        }.task {
//            image = try? await rf.workspace.projects[0].images().results.first {
//                ($0.annotations?.count ?? 0) > 1
//            }
//        }
//    }
//}
////
////public extension CGRect {
////    static func / (rect: Self, size: CGSize) -> Self {
////        var rect = rect
////        rect.size /= size
////        rect.origin /= size
////        return rect
////    }
////}
////
////extension CGSize {
////    static func /= (dividend: inout Self, divisor: Self) {
////        let simd = SIMD2(dividend) / .init(divisor)
////        dividend = .init(width: simd.x, height: simd.y)
////    }
////}
////
////extension CGPoint {
////    static func /= (dividend: inout Self, divisor: CGSize) {
////        let simd = SIMD2(dividend) / .init(divisor)
////        dividend = .init(x: simd.x, y: simd.y)
////    }
////}
////
////extension SIMD2 where Scalar == CGFloat.NativeType {
////    init(_ size: CGSize) {
////        self.init(size.width.native, size.height.native)
////    }
////    
////    init(_ point: CGPoint) {
////        self.init(point.x.native, point.y.native)
////    }
////}
//
import Roboflow
import Foundation
import CoreImage
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension CocoaImage {
    #if os(macOS)
    func ciImage() -> CIImage? {
        guard let data = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: data) else {
            return nil
        }
        let ci = CIImage(bitmapImageRep: bitmap)
        return ci
    }
    #else
    func ciImage() -> CIImage? {
        // If the UIImage already has an associated CIImage, return it
        if let ciImage = self.ciImage {
            return ciImage
        }
        
        // Otherwise, try to convert the UIImage to a CIImage
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        return CIImage(cgImage: cgImage)
    }
    #endif
}
