import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BookshelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }

            BookmarkListView()
                .tabItem {
                    Label("书签", systemImage: "bookmark")
                }
        }
    }
}
