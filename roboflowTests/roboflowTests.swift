import Testing
import CoreImage
@testable import roboflow_cocoa
import Foundation
#if os(macOS)
import AppKit
#endif
struct roboflowTests {
#if os(macOS)
    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let model = DataModel(labels: [
            "cucumber",
            "avocado",
            "tomato",
            "lemon"
        ])
        guard let url = Bundle.allBundles.compactMap({ $0.urlForImageResource("food_2") }).first else {
            fatalError("could not find test image")
        }
        model.lastImage = try .init(initialState: NSImage(data: Data.init(contentsOf: url))!.ciImage()!)
        await model.runModel()
        let fm = FileManager.default
        print(fm.temporaryDirectory)
        
        guard fm.fileExists(atPath: fm.temporaryDirectory.path()) else {
            fatalError()
        }
        guard fm.createFile(atPath: fm.temporaryDirectory.appending(path: "segmented_img.jpg").path(), contents: model.depthImage!.tiffRepresentation!) else {
            fatalError()
        }
    }
#endif
}
