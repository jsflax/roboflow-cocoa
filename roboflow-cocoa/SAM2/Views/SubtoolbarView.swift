//
//  SubtoolbarView.swift
//  SAM2-Demo
//
//  Created by Cyril Zakka on 9/8/24.
//

import SwiftUI

struct SubToolbar: View {
    @Binding var selectedPoints: [SAMPoint]
    @Binding var boundingBoxes: [SAMBox]
    @Binding var segmentationImages: [SAMSegmentation]
    @Binding var currentSegmentation: SAMSegmentation?

    var body: some View {
        if selectedPoints.count > 0 || boundingBoxes.count > 0 {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(height: 30)
                
                HStack {
                    Spacer()
                    Button("New Mask", action: newMask)
                        .padding(.trailing, 5)
                        .disabled(selectedPoints.isEmpty && boundingBoxes.isEmpty)
                    Button("Undo", action: undo)
                        .padding(.trailing, 5)
                        .disabled(selectedPoints.isEmpty && boundingBoxes.isEmpty)
                    Button("Reset", action: resetAll)
                        .padding(.trailing, 5)
                        .disabled(selectedPoints.isEmpty && boundingBoxes.isEmpty)
                    
                    
                }
            }
            .transition(.move(edge: .top))
            .onAppear {
                setupUndoShortcut()
            }
            .onDisappear {
                removeUndoShortCut()
            }
        }
    }
    
    func removeUndoShortCut() {
#if os(macOS)
        NSEvent.removeMonitor(undoHandler)
#endif
    }
    
    @State var undoHandler: Any? = nil
    func setupUndoShortcut() {
        #if os(macOS)
        self.undoHandler = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.characters == "z" {
                undo()
                return nil
            }
            return event
        }
        #endif
    }
    
    private func newMask() {
        if let currentSegmentation = self.currentSegmentation {
            self.segmentationImages.append(currentSegmentation)
            selectedPoints = []
            boundingBoxes = []
//            self.currentBox = nil
            self.currentSegmentation = nil
        }
    }

    private func resetAll() {
        selectedPoints.removeAll()
        boundingBoxes.removeAll()
        segmentationImages = []
        currentSegmentation = nil
    }
    
    private func undo() {
        if let lastPoint = selectedPoints.last, let lastBox = boundingBoxes.last {
            if lastPoint.dateAdded > lastBox.dateAdded {
                selectedPoints.removeLast()
            } else {
                boundingBoxes.removeLast()
            }
        } else if !selectedPoints.isEmpty {
            selectedPoints.removeLast()
        } else if !boundingBoxes.isEmpty {
            boundingBoxes.removeLast()
        }

        if selectedPoints.isEmpty && boundingBoxes.isEmpty {
            currentSegmentation = nil
        }
    }
}

#Preview {
    ContentView()
}

