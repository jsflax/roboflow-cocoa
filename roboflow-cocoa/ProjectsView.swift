import Foundation
import SwiftUI
import Roboflow

private extension Project {
    var lastEditedLabel: String {
        let calendar = Calendar.current
        
        let date = Date(timeIntervalSince1970: self.updated)
        // Calculate the difference between the two dates
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: .now)
        
        if let days = components.day, days > 0 {
            return "Edited \(days) day\(days > 1 ? "s" : "") ago"
        } else if let hours = components.hour, hours > 0 {
            return "Edited \(hours) hour\(hours > 1 ? "s" : "") ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "Edited \(minutes) minute\(minutes > 1 ? "s" : "") ago"
        } else {
            return "Edited just now"
        }
    }
}

// MARK: Projects View
struct ProjectsView: View {
    struct ProjectThumbnailView: View {
        let project: RFProject
        @State var coverURL: URL?
        
        var body: some View {
            HStack {
                if let coverURL = coverURL {
                    HStack {
                        WebImage(url: coverURL)
                            .padding(5)
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                        VStack(alignment: .leading) {
                            Text(project.type)
                                .font(.custom("caption", size: 9))
                                .frame(maxWidth: 80)
                                .background(RoundedRectangle(cornerRadius: 10).foregroundStyle(.bar))
                                .padding(.bottom, 3)
                            Text(project.name)
                            Text( project.lastEditedLabel).font(.caption.monospaced())
                        }
                    }
                } else {
                    ProgressView().task {
                        coverURL = URL(string: project.icon.thumb)!
                    }
                }
            }
        }
    }
    
    @State var projects: [RFProject]?
    
    var body: some View {
        VStack(alignment: .leading) {
            if let projects = projects {
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectView(project: project)
                    } label: {
                        ProjectThumbnailView(project: project)
                    }
                }.padding(3)
                    .padding(.top)
            } else {
                ProgressView().padding()
                    .task {
                        do {
                            self.projects = try await rf.workspace.projects
                        } catch {
                            print(error)
                        }
                    }
            }
            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var projects: [RFProject]?
    NavigationSplitView.init(sidebar: {
        EmptyView()
    }, detail: {
        if let projects = projects {
            ProjectsView(projects: projects)
        } else {
            ProgressView()
        }
    }).task {
        do {
            projects = try await rf.workspace.projects
        } catch {
            logger.critical("Error fetching projects: \(error)")
        }
    }
}
