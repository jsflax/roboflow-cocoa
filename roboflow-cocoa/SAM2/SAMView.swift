import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreML
import Vision
import os
import Roboflow

// TODO: Add reset, bounding box, and eraser

let logger = Logger(
    subsystem:
        "com.cyrilzakka.SAM2-Demo.ContentView",
    category: "ContentView")


struct PointsOverlay: View {
    @Binding var selectedPoints: [SAMPoint]
    @Binding var selectedTool: SAMTool?
    @Binding var imageSize: CGSize
    
    var body: some View {
        ForEach(selectedPoints, id: \.self) { point in
            Circle()
                .frame(width: 10, height: 10)
                .foregroundStyle(point.category.color)
                .position(point.coordinates.toSize(imageSize))
            
        }
    }
}

struct BoundingBoxesOverlay: View {
    let boundingBoxes: [SAMBox]
    let currentBox: SAMBox?
    let imageSize: CGSize
    
    var body: some View {
        ForEach(boundingBoxes) { box in
            BoundingBoxPath(box: box, imageSize: imageSize)
        }
        if let currentBox = currentBox {
            BoundingBoxPath(box: currentBox, imageSize: imageSize)
        }
    }
}

struct BoundingBoxPath: View {
    let box: SAMBox
    let imageSize: CGSize
    
    var body: some View {
        Path { path in
            path.move(to: box.startPoint.toSize(imageSize))
            path.addLine(to: CGPoint(x: box.endPoint.x, y: box.startPoint.y).toSize(imageSize))
            path.addLine(to: box.endPoint.toSize(imageSize))
            path.addLine(to: CGPoint(x: box.startPoint.x, y: box.endPoint.y).toSize(imageSize))
            path.closeSubpath()
        }
        .stroke(
            box.category.color,
            style: StrokeStyle(lineWidth: 2, dash: [5, 5])
        )
    }
}

struct SegmentationOverlay: View {
    @Binding var segmentationImage: SAMSegmentation
    @Binding var imageSize: CGSize

    
    @State var counter: Int = 0
    var origin: CGPoint = .zero
    var shouldAnimate: Bool = false
    
    @Binding var totalZoom: Double
    @Binding var offset: CGSize
    @Binding var currentScale: CGFloat
    
    var body: some View {
        let nsImage = CocoaImage(cgImage: segmentationImage.cgImage, size: imageSize)
        Image(cocoaImage: nsImage)
            .resizable()
//            .scaledToFit()
            .scaleEffect(currentScale)
//            .offset(offset)
            .allowsHitTesting(false)
//            .frame(width: imageSize.width, height: imageSize.height)
            .opacity(segmentationImage.isHidden ? 0:0.6)
            .modifier(RippleEffect(at: CGPoint(x: segmentationImage.cgImage.width/2, y: segmentationImage.cgImage.height/2), trigger: counter))
            .onAppear {
                if shouldAnimate {
                    counter += 1
                }
            }
    }
}

struct SAMView: View {
    let project: RFProject
    var classes: [String: Int] {
        project.classes
    }
    var labels: [String] {
        Array(classes.keys)
    }
    
    var colors: [String: String] {
        project.colors
    }
    
    // File importer
    let imageID: String
    @State var imageURL: URL
    
    // ML Models
    @StateObject private var sam2 = SAM2()
    @State private var currentSegmentation: SAMSegmentation?
    @State private var segmentationImages: [SAMSegmentation] = []
    @State private var imageSize: CGSize = .zero
    
    
    @State private var isImportingFromFiles: Bool = false
    @State private var displayImage: CocoaImage?
    
    // Mask exporter
    @State private var exportURL: URL?
    @State private var exportMaskToPNG: Bool = false
    @State private var showInspector: Bool = true
    @State private var selectedSegmentations = Set<SAMSegmentation.ID>()
    
    // Photos Picker
    @State private var isImportingFromPhotos: Bool = false
    @State private var selectedItem: PhotosPickerItem?
    
    @State private var error: Error?
    
    // ML Model Properties
    var tools: [SAMTool] = [pointTool, boundingBoxTool]
    var categories: [SAMCategory] = [.foreground, .background]
    
    @State private var selectedTool: SAMTool?
    @State private var selectedCategory: SAMCategory?
    @State private var selectedPoints: [SAMPoint] = []
    @State private var boundingBoxes: [SAMBox] = []
    @State private var currentBox: SAMBox?
    @State private var originalSize: CGSize?
    @State private var currentScale: CGFloat = 1.0
    @State private var visibleRect: CGRect = .zero
    @State private var toggleAutoAnnotation: Bool = false
    @FocusState var isFocused: Bool
    
    struct HostView: View {
        let sidebar: any View
        let detail: any View
        @Binding private var toggleAutoAnnotation: Bool
        @State private var logText: String = ""

        init(toggleAutoAnnotation: Binding<Bool>,
             sidebar: () -> any View,
             detail: () -> any View) {
            self.sidebar = sidebar()
            self.detail = detail()
            self._toggleAutoAnnotation = toggleAutoAnnotation
        }
        
        func redirectStdoutToTextView() {
            Task {
                // Create a Pipe to capture stdout
                let pipe = Pipe()
                dup2(pipe.fileHandleForWriting.fileDescriptor, fileno(stdout))
                
                // Read the output in the background
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if let line = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            logText = line
                        }
                    }
                }
            }
        }
        
        var body: some View {
            #if os(macOS)
            ZStack {
                HSplitView {
                    AnyView(sidebar)
                    AnyView(detail)
                }
                if toggleAutoAnnotation {
                    Rectangle().foregroundStyle(.black)
                        .opacity(0.5)
                    VStack {
                        ProgressView()
//                        Text(logText)
//                             .padding()
//                             .border(Color.gray, width: 1)
////                             .background(Color.white)
//                             .foregroundColor(.white)
//                             .font(.system(size: 14))
//                             .onAppear(perform: redirectStdoutToTextView)
                    }
                }
            }
            #else
            switch UIDevice.current.userInterfaceIdiom {
                case .phone:
                VStack {
                    ScrollView {
                        AnyView(sidebar)
                    }
                    AnyView(detail)
                }
                case .pad:
                HStack {
                    AnyView(sidebar)
                    Divider()
                    AnyView(detail)
                }
                 @unknown default:
                EmptyView()
                }
            
            #endif
        }
    }
    
    var sidebar: some View {
#if os(macOS)
        VStack {
            LayerListView(segmentationImages: $segmentationImages,
                          selectedSegmentations: $selectedSegmentations,
                          currentSegmentation: $currentSegmentation,
                          labels: labels,
                          colors: colors)
            
            Spacer()
            
            Button(action: {
                if let currentSegmentation = self.currentSegmentation {
                    self.segmentationImages.append(currentSegmentation)
                    self.reset()
                }
            }, label: {
                Text("New Mask")
            }).padding()
//                .keyboardShortcut(.return)
            Button("Export Selected...", action: {
                exportMaskToPNG = true
            }).padding()
        }.frame(minWidth: 200, maxWidth: 300)
#else
        VStack {
            Button("Export Selected...", action: {
                exportMaskToPNG = true
            }).padding()
            LayerListView(segmentationImages: $segmentationImages,
                          selectedSegmentations: $selectedSegmentations,
                          currentSegmentation: $currentSegmentation,
                          labels: labels,
                          colors: colors)
        }.frame(minWidth: 200, maxWidth: 300)
#endif
    }
    
    var body: some View {
        HostView(toggleAutoAnnotation: $toggleAutoAnnotation,
                 sidebar: {
            sidebar
        }, detail: {
            GeometryReader { geo in
                ZStack {
                    ZStack {
                        if let image = displayImage {
                            ImageView(image: image, currentScale: $currentScale, selectedTool: $selectedTool, selectedCategory: $selectedCategory, selectedPoints: $selectedPoints, boundingBoxes: $boundingBoxes, currentBox: $currentBox, segmentationImages: $segmentationImages, currentSegmentation: $currentSegmentation, imageSize: $imageSize, originalSize: $originalSize, sam2: sam2)
                            
                        } else {
                            ContentUnavailableView("No Image Loaded", systemImage: "photo.fill.on.rectangle.fill", description: Text("Please import a photo to get started."))
                        }
                    }
                    VStack(spacing: 0) {
                        SubToolbar(selectedPoints: $selectedPoints, boundingBoxes: $boundingBoxes, segmentationImages: $segmentationImages, currentSegmentation: $currentSegmentation)
                        Spacer()
                    }
                }
//                .frame(width: geo.size.width, height: geo.size.height/1.5)
            }.frame(minWidth: 400)
            .onAppear {
                setupReturnKeyMonitor()
                isFocused = true
            }
//            .inspector(isPresented: $showInspector, content: {
//                if selectedSegmentations.isEmpty {
//                    ContentUnavailableView(label: {
//                        Label(title: {
//                            Text("No Mask Selected")
//                                .font(.subheadline)
//                        }, icon: {})
//                        
//                    })
//                    .toolbar {
//                        Spacer()
//                        Button {
//                            showInspector.toggle()
//                        } label: {
//                            Label("Toggle Inspector", systemImage: "sidebar.trailing")
//                        }
//                    }
//                    .inspectorColumnWidth(min: 200, ideal: 200, max: 200)
//                } else {
//                    MaskEditor(exportMaskToPNG: $exportMaskToPNG, segmentationImages: $segmentationImages, selectedSegmentations: $selectedSegmentations, currentSegmentation: $currentSegmentation)
//                        .inspectorColumnWidth(min: 200, ideal: 200, max: 200)
//                        .toolbar {
//                            Spacer()
//                            Button {
//                                showInspector.toggle()
//                            } label: {
//                                Label("Toggle Inspector", systemImage: "sidebar.trailing")
//                            }
//                        }
//                }
//            })
            .toolbar {
                // Tools
                ToolbarItemGroup(placement: .principal) {
                    Picker(selection: $selectedTool, content: {
                        ForEach(tools, id: \.self) { tool in
                            Label(tool.name, systemImage: tool.iconName)
                                .tag(tool)
                                .labelStyle(.titleAndIcon)
                        }
                    }, label: {
                        Label("Tools", systemImage: "pencil.and.ruler")
                    })
                    .pickerStyle(.menu)
                    
                    Picker(selection: $selectedCategory, content: {
                        ForEach(categories, id: \.self) { cat in
                            Label(cat.name, systemImage: cat.iconName)
                                .tag(cat)
                                .labelStyle(.titleAndIcon)
                        }
                    }, label: {
                        Label("Tools", systemImage: "pencil.and.ruler")
                    })
                    .pickerStyle(.menu)
                    
                    // MARK: Toggle Auto Annotation
                    if #available(macOS 15.0, *) {
                        if #available(iOS 18.0, *) {
                            Button(action: {
                                self.toggleAutoAnnotation = true
                            }, label: {
                                Label("LlaVa Annotate", systemImage: "vision.pro")
                                    .labelStyle(.titleAndIcon)
                                    .accentColor(toggleAutoAnnotation ? .blue : nil)
                            })
                            .symbolEffect(.breathe,
                                          options: .repeat(.continuous),
                                          value: toggleAutoAnnotation)
                        }
                    } else {
                        // Fallback on earlier versions
                    }
                }
                
                // Import
                ToolbarItemGroup {
                    Menu {
                        Button(action: {
                            isImportingFromPhotos = true
                        }, label: {
                            Label("From Photos", systemImage: "photo.on.rectangle.fill")
                        })
                        
                        Button(action: {
                            isImportingFromFiles = true
                        }, label: {
                            Label("From Files", systemImage: "folder.fill")
                        })
                    } label: {
                        Label("Import", systemImage: "photo.badge.plus")
                    }
                }
            }
            
            .onAppear {
                if selectedTool == nil {
                    selectedTool = tools[0]
                }
                if selectedCategory == nil {
                    selectedCategory = categories.first
                }
                
            }
            .task {
                try? await sam2.ensureModelsAreLoaded()
                try? await loadImage(from: imageURL)
            }
            // MARK: - Image encoding
            .onChange(of: displayImage) {
                segmentationImages = []
                self.reset()
                Task {
                    if let displayImage, let pixelBuffer = displayImage.pixelBuffer(width: 1024, height: 1024) {
                        originalSize = displayImage.size
                        do {
                            try await sam2.getImageEncoding(from: pixelBuffer)
                        } catch {
                            self.error = error
                        }
                    }
                }
            }
            
            
            // MARK: - Photos Importer
            .photosPicker(isPresented: $isImportingFromPhotos, selection: $selectedItem, matching: .any(of: [.images, .screenshots, .livePhotos]))
            .onChange(of: selectedItem) {
                Task {
                    if let loadedData = try? await
                        selectedItem?.loadTransferable(type: Data.self) {
                        DispatchQueue.main.async {
                            selectedPoints.removeAll()
                            displayImage = CocoaImage(data: loadedData)
                        }
                    } else {
                        logger.error("Error loading image from Photos.")
                    }
                }
            }
            // MARK: Export Ann
            .onChange(of: exportMaskToPNG) {
                guard exportMaskToPNG else {
                    return
                }
                Task {
                    try await uploadAnnotation()
                }
            }
            .onChange(of: toggleAutoAnnotation) {
                guard toggleAutoAnnotation else {
                    return
                }
                Task {
                    try await self.runAutoAnnotator()
                }
            }
            .onDisappear {
                #if os(macOS)
                NSEvent.removeMonitor(self.keyHandler)
                #endif
            }
            .onKeyPress(characters: .alphanumerics, action: { keyPress in
                print(keyPress.modifiers)
                return .handled
            })
            .focusable()
//
            .focused($isFocused)
//            .onKeyPress {
//                print($0)
//                return .ignored
//            }
//            .onKeyPress(.return) {
//                print("Return key pressed!")
//                if let currentSegmentation = self.currentSegmentation {
//                    self.segmentationImages.append(currentSegmentation)
//                    if self.toggleAutoAnnotation {
//                        Task {
//                            saveImage(createCompositeImage(segmentation: currentSegmentation)!,
//                                            to: FileManager.default.temporaryDirectory.appending(path: "tmp_seg.jpg"))
//                            let prediction = try await Llava.shared.llavaPrediction(imagePath: FileManager.default.temporaryDirectory.appending(path: "tmp_seg.jpg").path(), labels: labels, hint: nil)
//                            if let index = self.segmentationImages.firstIndex { $0.id == currentSegmentation.id } {
//                                self.segmentationImages[
//                                    index
//                                ].title = prediction.classLabel
//                            }
//                            print(prediction)
//                        }
//                    }
//                    self.reset()
//                    return .handled
//                }
//                return .ignored
//            }
            // MARK: - File Importer
            //        .fileImporter(isPresented: $isImportingFromFiles,
            //                      allowedContentTypes: [.image]) { result in
            //            switch result {
            //            case .success(let file):
            //                self.selectedItem = nil
            //                self.selectedPoints.removeAll()
            //                self.imageURL = file
            //                Task {
            //                    do {
            //                        try await loadImage(from: file)
            //                    } catch {
            //                        print(error)
            //                    }
            //                }
            //            case .failure(let error):
            //                logger.error("File import error: \(error.localizedDescription)")
            //                self.error = error
            //            }
            //        }
            
            // MARK: - File exporter
//            .fileExporter(
//                isPresented: $exportMaskToPNG,
//                document: DirectoryDocument(initialContentType: .folder),
//                contentType: .folder,
//                defaultFilename: "Segmentations"
//            ) { result in
//                if case .success(let url) = result {
//                    exportURL = url
//                    var selectedToExport = segmentationImages.filter { segmentation in
//                        selectedSegmentations.contains(segmentation.id)
//                    }
//                    if let currentSegmentation {
//                        selectedToExport.append(currentSegmentation)
//                    }
//                    exportSegmentations(selectedToExport, to: url)
//                }
//            }
        })
    }
    
    // MARK: Run Auto Annotator
    func runAutoAnnotator() async throws {
        #if os(macOS)
        let ids: [UUID] = self.selectedSegmentations.map { $0 } // to maintain order since its a set
        let imagePaths = ids.map { id in
            let seg = self.segmentationImages.first(where: { $0.id == id })!
            let compositeImg: CocoaImage
            if seg.shouldCropForAutoAnnotate {
                compositeImg = createCroppedMaskImage(segmentation: seg)!
            } else {
                compositeImg = createCompositeImage(segmentation: seg)!
            }
            saveImage(compressImage(compositeImg, compressionFactor: 0.6)!,
                      to: FileManager.default.temporaryDirectory.appending(path: "tmp_seg_\(id).jpg"))
            return FileManager.default.temporaryDirectory.appending(path: "tmp_seg_\(id).jpg").path()
        }
        let predictions = try await Llava.shared.llavaPrediction(imagePaths: imagePaths, labels: labels, hint: nil)
        for i in 0..<ids.count {
            print(predictions[i])
            let idx = self.segmentationImages.firstIndex { $0.id == ids[i] }!
            self.segmentationImages[idx].title = predictions[i].classLabel
            self.segmentationImages[idx].tintColor = Color(hex: project.colors[predictions[i].classLabel]!)
        }
        #endif
        self.toggleAutoAnnotation = false
    }
    
    func uploadAnnotation() async throws {
        let yoloAnnotations = generateYOLOAnnotations(segmentations: self.segmentationImages, classMapping: self.classes)
        try await project.upload(darknetAnnotation: yoloAnnotations, for: imageID)
        self.exportMaskToPNG = false
    }
    
    // MARK: - Private Methods
    private func loadImage(from url: URL) async throws {
        
//        guard url.startAccessingSecurityScopedResource() else {
//            logger.error("Failed to access the file. Security-scoped resource access denied.")
//            return
//        }
//
//        defer { url.stopAccessingSecurityScopedResource()
//        }
        
        do {
            let imageData: Data
            if url.absoluteString.contains("http") {
                imageData = try await URLSession.shared.data(from: url).0
            } else {
                imageData = try Data(contentsOf: url)
            }
            if let image = CocoaImage(data: imageData) {
                DispatchQueue.main.async {
                    self.displayImage = image
                }
            } else {
                logger.error("Failed to create NSImage from file data")
            }
        } catch {
            logger.error("Error loading image data: \(error.localizedDescription)")
            self.error = error
        }
    }
    
    func exportSegmentations(_ segmentations: [SAMSegmentation], to directory: URL) {
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            
            for (index, segmentation) in segmentations.enumerated() {
                let filename = "segmentation_\(index + 1).png"
                let fileURL = directory.appendingPathComponent(filename)
                
                if let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, segmentation.cgImage, nil)
                    if CGImageDestinationFinalize(destination) {
                        print("Saved segmentation \(index + 1) to \(fileURL.path)")
                    } else {
                        print("Failed to save segmentation \(index + 1)")
                    }
                }
            }
        } catch {
            print("Error creating directory: \(error.localizedDescription)")
        }
    }
    
    private func reset() {
        selectedPoints = []
        boundingBoxes = []
        currentBox = nil
        currentSegmentation = nil
    }
    @State private var keyHandler: Any? = nil
    
    func setupReturnKeyMonitor() {
        #if os(macOS)
        self.keyHandler = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            if event.keyCode == 6 && event.modifierFlags == .command {
                print("undo")
            }
            if event.keyCode == 36 { // Return key's keyCode is 36
                print("Return key pressed!")
                if let currentSegmentation = self.currentSegmentation {
                    self.segmentationImages.append(currentSegmentation)
                    self.reset()
                }
                return nil // Return nil to prevent propagation
            }
            return event
        }
        #endif
    }
    
    func saveImage(_ image: CocoaImage, to url: URL) {
        #if os(macOS)
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to get PNG data from image.")
            return
        }
        #else
        guard let pngData = image.pngData() else {
            print("Failed to get PNG data from image.")
            return
        }
        #endif
        do {
            try pngData.write(to: url)
            print("Image saved to \(url.path)")
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    func computeBoundingBox(from maskCGImage: CGImage) -> CGRect? {
        let width = maskCGImage.width
        let height = maskCGImage.height

        guard let dataProvider = maskCGImage.dataProvider,
              let data = dataProvider.data,
              let pixelData = CFDataGetBytePtr(data) else {
            print("Failed to get pixel data from mask CGImage.")
            return nil
        }

        let bytesPerRow = maskCGImage.bytesPerRow
        let bytesPerPixel = maskCGImage.bitsPerPixel / 8

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var hasNonZeroPixel = false

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                let alpha = pixelData[pixelIndex + 3] // Assuming RGBA format

                if alpha != 0 {
                    hasNonZeroPixel = true
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        if hasNonZeroPixel {
            // Adjust for coordinate system (origSin at bottom-left)
            let rect = CGRect(
                x: CGFloat(minX),
                y: CGFloat(height - maxY - 1),
                width: CGFloat(maxX - minX + 1),
                height: CGFloat(maxY - minY + 1)
            )
            return rect
        } else {
            // No non-zero pixels found
            return nil
        }
    }
    
    func desaturateImage(_ image: CIImage) -> CIImage? {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = 0.0
        return filter.outputImage
    }
    func compositeImages(originalImage: CIImage, desaturatedImage: CIImage, maskImage: CIImage) -> CIImage? {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = originalImage
        filter.backgroundImage = desaturatedImage
        filter.maskImage = maskImage
        return filter.outputImage
    }
    #if os(macOS)
    func compressImage(_ image: NSImage, compressionFactor: CGFloat) -> NSImage? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]) else {
            print("Failed to compress image")
            return nil
        }

        return NSImage(data: jpegData)
    }
    #endif
    #if os(macOS)
    func createCroppedMaskImage(segmentation: SAMSegmentation) -> CocoaImage? {
        // Ensure original image and mask are available
        guard let originalCIImage = displayImage!.ciImage() else {
            print("Original image is missing.")
            return nil
        }
        
        // Resize the mask to match the original image size
        let maskCIImage = segmentation.image.resized(to: originalCIImage.extent.size)
        
        // Compute the bounding box from the mask image
        guard let boundingBox = computeBoundingBox(from: segmentation.cgImage.resized(to: originalCIImage.extent.size)!) else {
            print("Failed to compute bounding box from mask.")
            return nil
        }

        // Crop the original image based on the bounding box
        let croppedOriginalImage = originalCIImage.cropped(to: boundingBox)
        
        // Apply the mask to the cropped image
        guard let maskedImage = applyMask(originalImage: croppedOriginalImage, maskImage: maskCIImage.cropped(to: boundingBox)) else {
            print("Failed to apply mask to the cropped image.")
            return nil
        }

        // Convert the cropped and masked CIImage to NSImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(maskedImage, from: maskedImage.extent) else {
            print("Failed to create CGImage from masked image.")
            return nil
        }

        return NSImage(cgImage: cgImage, size: boundingBox.size)
    }

    func applyMask(originalImage: CIImage, maskImage: CIImage) -> CIImage? {
        let maskFilter = CIFilter(name: "CIBlendWithAlphaMask")
        maskFilter?.setValue(originalImage, forKey: kCIInputImageKey)
        maskFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
        return maskFilter?.outputImage
    }
    
    func createCompositeImage(segmentation: SAMSegmentation) -> CocoaImage? {
        // Ensure original image and mask are available
        guard let originalCIImage = displayImage!.ciImage() else {
            print("Original image or mask is missing.")
            return nil
        }
        let maskCIImage = segmentation.image.resized(to: originalCIImage.extent.size)
        // Desaturate the original image
        guard let desaturatedCIImage = desaturateImage(originalCIImage) else {
            print("Failed to desaturate the original image.")
            return nil
        }

        // Composite the images using the mask
        guard let compositedCIImage = compositeImages(
            originalImage: originalCIImage,
            desaturatedImage: desaturatedCIImage,
            maskImage: maskCIImage
        ) else {
            print("Failed to composite images.")
            return nil
        }

        // Convert composited CIImage to NSImage
        let compositedNSImage = NSImage(size: originalCIImage.extent.size)
        let context = CIContext()
        if let cgImage = context.createCGImage(compositedCIImage, from: compositedCIImage.extent) {
            compositedNSImage.addRepresentation(NSBitmapImageRep(cgImage: cgImage))
        } else {
            print("Failed to create CGImage from composited CIImage.")
            return nil
        }

        // Compute the bounding box from the mask image
        guard let boundingBox = computeBoundingBox(from: segmentation.cgImage.resized(to: originalCIImage.extent.size)!) else {
            print("Failed to compute bounding box from mask.")
            return nil
        }

        // Draw the bounding box over the composited image
        let imageSize = compositedNSImage.size
        let finalImage = NSImage(size: imageSize)

        finalImage.lockFocus()

        // Draw the composited image
        compositedNSImage.draw(at: .zero, from: CGRect(origin: .zero, size: imageSize), operation: .copy, fraction: 1.0)

        // Draw the bounding box
        let path = NSBezierPath(rect: boundingBox)
        NSColor.red.setStroke()
        path.lineWidth = 2.0
        path.stroke()

        finalImage.unlockFocus()

        return finalImage
    }
    #else
    func createCompositeImage(segmentation: SAMSegmentation) -> UIImage? {
        // Ensure original image and mask are available
        guard let originalCIImage = displayImage?.ciImage() else {
            print("Original image or mask is missing.")
            return nil
        }
        let maskCIImage = segmentation.image

        // Desaturate the original image
        guard let desaturatedCIImage = desaturateImage(originalCIImage) else {
            print("Failed to desaturate the original image.")
            return nil
        }

        // Composite the images using the mask
        guard let compositedCIImage = compositeImages(
            originalImage: originalCIImage,
            desaturatedImage: desaturatedCIImage,
            maskImage: maskCIImage
        ) else {
            print("Failed to composite images.")
            return nil
        }

        // Convert composited CIImage to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(compositedCIImage, from: compositedCIImage.extent) else {
            print("Failed to create CGImage from composited CIImage.")
            return nil
        }
        let compositedUIImage = UIImage(cgImage: cgImage)

        // Compute the bounding box from the mask image
        guard let boundingBox = computeBoundingBox(from: segmentation.cgImage) else {
            print("Failed to compute bounding box from mask.")
            return nil
        }

        // Draw the bounding box over the composited image
        let imageSize = compositedUIImage.size
        UIGraphicsBeginImageContextWithOptions(imageSize, false, compositedUIImage.scale)
        guard let graphicsContext = UIGraphicsGetCurrentContext() else {
            print("Failed to get graphics context.")
            return nil
        }

        // Draw the composited image
        compositedUIImage.draw(at: CGPoint.zero)

        // Draw the bounding box
        graphicsContext.setStrokeColor(UIColor.red.cgColor)
        graphicsContext.setLineWidth(2.0)

        // Adjust bounding box for UIKit coordinate system
        let adjustedBoundingBox = CGRect(
            x: boundingBox.origin.x,
            y: imageSize.height - boundingBox.origin.y - boundingBox.height,
            width: boundingBox.width,
            height: boundingBox.height
        )

        let path = UIBezierPath(rect: adjustedBoundingBox)
        path.stroke()

        // Get the final image
        let finalImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return finalImage
    }
    #endif
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

#Preview {
    SAMView(project: ._test,
            imageID: "",
            imageURL: URL(string: "https://images.services.kitchenstories.io/gxInWDQniM21aQiVgvnXmDrMnvo=/3840x0/filters:quality(85)/images.kitchenstories.io/communityImages/f4604e05f6a9eaca99afddd69e849005_c02485d4-0841-4de6-b152-69deb38693f2.jpg")!)
}
