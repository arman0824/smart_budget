import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview("Smart Budget") {
    ContentView()
        .environmentObject(PreviewSupport.store)
        .modelContainer(PreviewSupport.container)
}
