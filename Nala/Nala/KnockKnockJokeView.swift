//
//  KnockKnockJokeView.swift
//  Nala
//
//  Created by Robin Kanatzar on 10/3/25.
//

import SwiftUI

struct KnockKnockJokeView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("The funniest application you've ever downloaded.")
                HStack {
                    Button("Tell me a joke.") {
                        // TODO
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Knock Knock Jokes")
        }
    }
}

#Preview {
    KnockKnockJokeView()
}
