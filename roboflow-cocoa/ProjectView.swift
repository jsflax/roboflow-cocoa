//
//  ProjectView.swift
//  roboflow-cocoa
//
//  Created by Jason Flax on 9/17/24.
//

import Foundation
import SwiftUI
import Roboflow

struct ProjectView: View {
    let project: RFProject
    @State var images: [RFImageCompact] = []
    @State var classSelection: String? = nil
    @State var labels: [String?]
    @State var searchText: String = ""
    
    init(project: RFProject) {
        self.project = project
        self.labels = [nil, "null"] + project.classes.keys.sorted()
    }
    
    var body: some View {
        ScrollView {
            if !images.isEmpty {
                LazyVGrid(columns: [.init(), .init(), .init(), .init(), .init()], content: {
                    ForEach(images, content: { image in
                        NavigationLink(destination: {
                            SAMView(project: project,
                                    imageID: image.id,
                                    imageURL: URL(string: String(format: project.templateOriginalImageURL, image.id))!)
                            .navigationTitle(image.name ?? image.id)
                        }, label: {
                            ZStack {
                                WebImage(url: URL(string: String(format: project.templateThumbImageURL, image.id))!)
                                .frame(width: 100, height: 100)
                                if image.annotations != nil {
                                    WebImage(url: URL(string: String(format: project.templateAnnotationImageURL!, image.id))!).frame(width: 100, height: 100)
                                }
                            }
                        })
                    })
                }).padding()
            } else {
                ProgressView()
            }
        }
        .onChange(of: classSelection, {
            self.images.removeAll()
            Task {
                self.images = try! await project.images(className: classSelection).results
            }
        })
        .task {
            self.images = try! await project.images(likeImage: searchText.isEmpty ? nil : searchText, className: classSelection).results
        }
        .onChange(of: searchText) {
            Task {
                self.images = try! await project.images(prompt: searchText.isEmpty ? nil : searchText, className: classSelection).results
            }
        }
        .navigationTitle(project.name)
        .navigationBarBackButtonHidden(false)
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem {
                classPicker
            }
        }
    }
    
    var classPicker: some View {
        Picker("Classes", selection: $classSelection, content: {
            ForEach(labels, id: \.self) { key in
                if let key = key {
                    Label(key, systemImage:
                            key == "null" ? "circle.slash" : "circle.circle.fill")
                        .tint(Color(hex: project.colors[key] ?? "#AA4A44"))
                        .labelStyle(.titleAndIcon)
                        .id(key)
                        .tag(key)
                } else {
                    Label("all classes", systemImage: "circle")
                        .tint(Color(hex: "#000000"))
                        .labelStyle(.titleAndIcon)
                        .id(key)
                        .tag(key)
                }
            }
        }).pickerStyle(.menu)
    }
}

#Preview {
    @Previewable @State var project: RFProject?
    NavigationSplitView {
        EmptyView()
    } detail: {
        if let project = project {
            NavigationStack {
                ProjectView(project: project)
            }
        } else {
            ProgressView().task {
                project = try? await rf.workspace.projects[0]
            }
        }
    }
}
