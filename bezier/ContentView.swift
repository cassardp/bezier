import SwiftUI

struct ContentView: View {
    @State private var store = CanvasStore()

    var body: some View {
        InfiniteCanvasView(store: store)
    }
}

#Preview {
    ContentView()
}
