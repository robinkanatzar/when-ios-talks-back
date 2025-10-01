import SwiftUI
import AVFoundation

struct Example6View: View {
    let synthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: "Knock knock. Who's there? Boo. Boo who? Don't cry. It's just a joke!")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Press the button and hear AVSpeechSynthesizer tell you a joke.")
            Text("AVAudioSession options is set to .mixWithOthers, so VoiceOver will be louder than AVSpeechSynthesizer if they are speaking at the same time.")
            Text("AVSpeechSynthesizer \"mixes\" politely or plays nicely with VoiceOver, letting its volume be turned down by VoiceOver.")
            Text("(Make sure your phone is not in silent mode.)")
            
            HStack {
                Button("Tell me a joke.") {
                    synthesizer.speak(utterance)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Example 6: Joke .mixWithOthers")
        .onAppear {
            setupAudioSession()
        }
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

#Preview {
    Example6View()
}
