import SwiftUI
import Roboflow

let rf = RoboflowMobile(apiKey: "noPIlA0IKv3lhI6wML6j")

enum SidebarCommands {
    case projects
}

struct WebImage: View {
    let url: URL
    
    @State var data: Data?
    
    var body: some View {
        if let data = data, let image = CocoaImage(data: data) {
            Image(cocoaImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ProgressView().task {
                data = try? await URLSession.shared.data(from: url).0
            }
        }
    }
}

struct DetailView: View {
    @Binding var selection: SidebarCommands
    
    var body: some View {
        switch selection {
        case .projects:
            ProjectsView()
        }
    }
}

struct ContentView: View {
    @State var selection: SidebarCommands = .projects
    
    var body: some View {
        #if os(macOS)
        NavigationSplitView(sidebar: {
            VStack {
                Button("Projects") {
                    selection = .projects
                }
            }
            .padding()
        }, detail: {
            NavigationStack {
                DetailView(selection: $selection)
            }
        }).navigationTitle("Roboflow")
        .navigationBarBackButtonHidden(false)
        #else
        NavigationStack {
            DetailView(selection: $selection)
        }.navigationTitle("Roboflow")
        #endif
    }
}

#Preview {
    ContentView()
}
