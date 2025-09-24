//
//  ContentView.swift
//  Snippets
//
//  Created by Montana  on 9/24/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                NavigationLink {
                    Example1View()
                } label: {
                    Text("Example 1")
                }
                NavigationLink {
                    Example2View()
                } label: {
                    Text("Example 2")
                }
                NavigationLink {
                    Example3View()
                } label: {
                    Text("Example 3")
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
