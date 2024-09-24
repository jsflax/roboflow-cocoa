//
//  LayerListView.swift
//  SAM2-Demo
//
//  Created by Cyril Zakka on 9/8/24.
//

import SwiftUI

struct AnimationProperties {
    var scaleValue: CGFloat = 1.0
}

struct RadioButton: View {
    @Binding private var selection: String?
    var isSelected: Bool {
        selection == label
    }
    private let label: String
    private var isDisabled: Bool = false
    @State private var animate: Bool = false
    
    init(isSelected: Binding<String?>, label: String = "") {
        self._selection = isSelected
        self.label = label
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            circleView
            labelView
        }
        .contentShape(Rectangle())
//        .onTapGesture { selection = label }
        .disabled(isDisabled)
    }
}

extension RadioButton {
    var innerCircleColor: Color {
        return isSelected ? Color.blue : Color.clear
    }
    
    var outlineColor: Color {
        return isSelected ? Color.blue : Color.gray
    }
    
    @ViewBuilder var labelView: some View {
        Text(label)
    }
}

private extension RadioButton {
    //...
    
    @ViewBuilder var circleView: some View {
        Circle()
            .fill(innerCircleColor) // Inner circle color
            .animation(.easeInOut(duration: 0.15), value: isSelected)
            .padding(4)
            .overlay(
                Circle()
                    .stroke(outlineColor, lineWidth: 1)
            ) // Circle outline
            .frame(width: 20, height: 20)
            .keyframeAnimator(
                initialValue: AnimationProperties(), trigger: animate,
                content: { content, value in
                    content
                        .scaleEffect(value.scaleValue)
                },
                keyframes: { _ in
                    KeyframeTrack(\.scaleValue) {
                        CubicKeyframe(0.9, duration: 0.05)
                        CubicKeyframe(1.10, duration: 0.15)
                        CubicKeyframe(1, duration: 0.25)
                    }
                })
            .onChange(of: isSelected) { _, newValue in
                if newValue == true {
                    animate.toggle()
                }
            }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct LayerListView: View {
    @Binding var segmentationImages: [SAMSegmentation]
    @Binding var selectedSegmentations: Set<SAMSegmentation.ID>
    @State var selectedClass: String?
    @Binding var currentSegmentation: SAMSegmentation?
    let labels: [String]
    let colors: [String: String]
    
    var body: some View {
        List(selection: $selectedSegmentations) {
            Section("Annotations List") {
                ForEach(Array(segmentationImages.enumerated()), id: \.element.id) { index, segmentation in
                    AnnotationListView(segmentation: $segmentationImages[index])
                        .padding(.horizontal, 5)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let index = segmentationImages.firstIndex(where: { $0.id == segmentation.id }) {
                                    segmentationImages.remove(at: index)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
                
                if let currentSegmentation = currentSegmentation {
                    AnnotationListView(segmentation: .constant(currentSegmentation))
                        .tag(currentSegmentation.id)
                }
            }
            Section("Class List") {
                ForEach(labels, id: \.self) { label in
                    RadioButton(isSelected: $selectedClass, label: label)
                        .padding(.horizontal, 5)
                        .onTapGesture {
                            selectedClass = label
                            for i in 0..<segmentationImages.count
                            where selectedSegmentations.contains(segmentationImages[i].id) {
                                segmentationImages[i].title = label
                                segmentationImages[i].tintColor = Color(hex: colors[label]!)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    func delete(at offsets: IndexSet) {
        segmentationImages.remove(atOffsets: offsets)
    }
    
    func move(from source: IndexSet, to destination: Int) {
        segmentationImages.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    ContentView()
}
