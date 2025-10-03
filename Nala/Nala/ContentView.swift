import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NavigationLink {
                        Example1View()
                    } label: {
                        HStack {
                            Text("Example 1: Utterance")
                            Spacer()
                        }
                    }
                    NavigationLink {
                        Example2View()
                    } label: {
                        Text("Example 2: Utterance \"Knock Knock\"")
                    }
                    NavigationLink {
                        Example3View()
                    } label: {
                        Text("Example 3: .duckOthers")
                    }
                    NavigationLink {
                        Example4View()
                    } label: {
                        Text("Example 4: .mixWithOthers")
                    }
                    NavigationLink {
                        Example5View()
                    } label: {
                        Text("Example 5: Is VoiceOver on?")
                    }
                    NavigationLink {
                        Example6View()
                    } label: {
                        Text("Example 6: Joke .mixWithOthers")
                    }
                    NavigationLink {
                        Example7View()
                    } label: {
                        Text("Example 7: Joke When VoiceOver Off")
                    }
                    NavigationLink {
                        Example8View()
                    } label: {
                        Text("Example 8: Toggle Text View")
                    }
                    NavigationLink {
                        Example9View()
                    } label: {
                        Text("Example 9: ")
                    }
                    
                    Divider()
                    
                    NavigationLink {
                        Example10View()
                    } label: {
                        Text("Example 10: Joke phone talks to itself")
                    }
                    NavigationLink {
                        SelfTalkView()
                    } label: {
                        Text("Self Talk View")
                    }
                    NavigationLink {
                        KnockKnockJokeView()
                    } label: {
                        Text("Knock Knock Jokes View")
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("When iOS Talks Back")
        }
    }
}
