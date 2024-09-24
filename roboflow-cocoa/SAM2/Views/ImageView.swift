//
//  ImageView.swift
//  SAM2-Demo
//
//  Created by Cyril Zakka on 9/8/24.
//

import SwiftUI
import Roboflow

struct ImageView: View {
    let image: CocoaImage
    @Binding var currentScale: CGFloat
    @Binding var selectedTool: SAMTool?
    @Binding var selectedCategory: SAMCategory?
    @Binding var selectedPoints: [SAMPoint]
    @Binding var boundingBoxes: [SAMBox]
    @Binding var currentBox: SAMBox?
    @Binding var segmentationImages: [SAMSegmentation]
    @Binding var currentSegmentation: SAMSegmentation?
    @Binding var imageSize: CGSize
    @Binding var originalSize: CGSize?
    @State private var originalImageSize: CGSize = .zero
    
    @State var animationPoint: CGPoint = .zero
    @ObservedObject var sam2: SAM2
    @State private var error: Error?
    
    var pointSequence: [SAMPoint] {
        boundingBoxes.flatMap { $0.points } + selectedPoints
    }
    
    @State private var totalZoom = 1.0
    @State private var offset = CGSize.zero
    @State private var imageFrame: CGRect = .zero
    @State private var viewFrame: CGRect = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    // Magnification Gesture
    var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = lastScale * value
            }
            .onEnded { value in
                lastScale = currentScale
            }
    }
    
    // Drag Gesture
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                lastOffset = offset
            }
    }

    
    var body: some View {
        GeometryReader { outerGeometry in
            let originalImageSize = image.size
            let availableSize = outerGeometry.size

            ZStack {
                Image(cocoaImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .onPreferenceChange(ViewFramePreferenceKey.self) { frame in
                        self.viewFrame = frame
                    }
                //                .scaleEffect(currentScale)
                    .onPreferenceChange(FramePreferenceKey.self) { frame in
                        self.imageFrame = frame
                        self.imageSize = frame.size
                    }
                    .scaleEffect(currentScale)
                //                .offset(offset)
//                    .gesture(
//                        MagnificationGesture()
//                            .onChanged { value in
//                                currentScale = value
//                            }
//                    )
//                    .gesture(
//                        DragGesture()
//                            .onChanged { value in
//                                offset = value.translation
//                            }
//                    )
                    .onTapGesture { location in
                        handleTap(at: location)
                    }
                    .gesture(boundingBoxGesture)
                    .onHover { changeCursorAppearance(is: $0) }
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: SizePreferenceKey.self, value: geometry.size)
                    })
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: FramePreferenceKey.self, value: geometry.frame(in: .global))
                        }
                    )
                    .onPreferenceChange(SizePreferenceKey.self) {
                        imageSize = $0
                    }
                    .onChange(of: selectedPoints.count, {
                        if !selectedPoints.isEmpty {
                            performForwardPass()
                        }
                    })
                    .onChange(of: boundingBoxes.count, {
                        if !boundingBoxes.isEmpty {
                            performForwardPass()
                        }
                    })
                    .overlay {
                        PointsOverlay(selectedPoints: $selectedPoints, selectedTool: $selectedTool, imageSize: $imageSize)
                        BoundingBoxesOverlay(boundingBoxes: boundingBoxes, currentBox: currentBox, imageSize: imageSize)
                        
                        if !segmentationImages.isEmpty {
                            ForEach(Array(segmentationImages.enumerated()), id: \.element.id) { index, segmentation in
                                SegmentationOverlay(segmentationImage: $segmentationImages[index], imageSize: $imageSize, shouldAnimate: false, totalZoom: $totalZoom,
                                                    offset: $offset,
                                                    currentScale: $currentScale)
                                .zIndex(Double (segmentationImages.count - index))
                            }
                        }
                        
                        if let currentSegmentation = currentSegmentation {
                            SegmentationOverlay(segmentationImage: .constant(currentSegmentation), imageSize: $imageSize, origin: animationPoint.toSize(imageSize), shouldAnimate: true, totalZoom: $totalZoom,
                                                offset: $offset,
                                                currentScale: $currentScale)
                            .zIndex(Double(segmentationImages.count + 1))
                        }
                    }
            }
        }
    }
    
    private func changeCursorAppearance(is inside: Bool) {
        #if os(macOS)
        if inside {
            if selectedTool == pointTool {
                NSCursor.pointingHand.push()
            } else if selectedTool == boundingBoxTool {
                NSCursor.crosshair.push()
            }
        } else {
            NSCursor.pop()
        }
        #endif
    }
    
    private var boundingBoxGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard selectedTool == boundingBoxTool else { return }
                
                if currentBox == nil {
                    currentBox = SAMBox(startPoint: value.startLocation.fromSize(imageSize), endPoint: value.location.fromSize(imageSize), category: selectedCategory!)
                } else {
                    currentBox?.endPoint = value.location.fromSize(imageSize)
                }
            }
            .onEnded { value in
                guard selectedTool == boundingBoxTool else { return }
                
                if let box = currentBox {
                    boundingBoxes.append(box)
                    animationPoint = box.midpoint.toSize(imageSize)
                    currentBox = nil
                }
            }
    }
    
    private func handleTap(at location: CGPoint) {
        if selectedTool == pointTool {
            // Convert the tap location to the image coordinate system
            print("tapped", location)
//            let imagePoint =
            // Use 'imagePoint' for further processing
            placePoint(at: location)
            animationPoint = location
        }
    }
    
    func mapTappedPointToImage(tapLocation: CGPoint, imageSize: CGSize, availableSize: CGSize, scale: CGFloat, offset: CGSize) -> CGPoint? {
        // Step 1: Calculate the actual size of the image on the screen after scaling (keeping the aspect ratio)
        let aspectWidth = availableSize.width / imageSize.width
        let aspectHeight = availableSize.height / imageSize.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        let scaledImageSize = CGSize(width: imageSize.width * aspectRatio * scale, height: imageSize.height * aspectRatio * scale)
        
        // Step 2: Find the position of the image inside the view (it may not be at (0,0) due to centering)
        let imageXOffset = (availableSize.width - scaledImageSize.width) / 2.0
        let imageYOffset = (availableSize.height - scaledImageSize.height) / 2.0
        
        // Step 3: Adjust the tap point based on the offset (dragging) and centering
        let adjustedTapX = tapLocation.x - offset.width - imageXOffset
        let adjustedTapY = tapLocation.y - offset.height - imageYOffset
        
        // Step 4: Ensure the tap is within the image bounds
        guard adjustedTapX >= 0, adjustedTapY >= 0, adjustedTapX <= scaledImageSize.width, adjustedTapY <= scaledImageSize.height else {
            return nil // Tap was outside the image bounds
        }
        
        // Step 5: Convert the tapped point to the original image's coordinate space
        let imageX = adjustedTapX / (aspectRatio * scale)
        let imageY = adjustedTapY / (aspectRatio * scale)
        
        return CGPoint(x: imageX, y: imageY)
    }
    
    private func placePoint(at coordinates: CGPoint) {
//        print("coords", coordinates)
        print("coords (normalized)", coordinates.fromSize(imageSize))
        let samPoint = SAMPoint(coordinates: coordinates.fromSize(imageSize),
                                category: selectedCategory!)
        self.selectedPoints.append(samPoint)
    }
    
    private func performForwardPass() {
        Task {
            do {
                try await sam2.getPromptEncoding(from: pointSequence, with: imageSize)
                if let mask = try await sam2.getMask(for: originalSize ?? .zero) {
                    Task { @MainActor in
                        let segmentationNumber = segmentationImages.count
                        let segmentationOverlay = SAMSegmentation(image: mask, title: "Untitled \(segmentationNumber + 1)")
                        self.currentSegmentation = segmentationOverlay
                    }
                }
            } catch {
                self.error = error
            }
        }
    }
}

struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
struct ViewFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
#Preview {
    SAMView(project: ._test,
            imageID: "",
            imageURL: URL(string: "https://images.services.kitchenstories.io/gxInWDQniM21aQiVgvnXmDrMnvo=/3840x0/filters:quality(85)/images.kitchenstories.io/communityImages/f4604e05f6a9eaca99afddd69e849005_c02485d4-0841-4de6-b152-69deb38693f2.jpg")!)
}

extension CGPoint {
    func fromSize(_ size: CGSize) -> CGPoint {
        CGPoint(x: x / size.width, y: y / size.height)
    }

    func toSize(_ size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}

extension CGSize {
    static func *(_ lhs: CGSize, _ rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
    static func *=(_ lhs: inout CGSize, _ rhs: CGFloat) {
        lhs = CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }
}
