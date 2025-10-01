import SwiftUI
import AVFoundation

struct Example2View: View {
    let synthesizer = AVSpeechSynthesizer()
    let utterance = AVSpeechUtterance(string: "Knock knock.")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Press the button and hear AVSpeechSynthesizer say \"Knock knock.\"")
            Text("(Make sure your phone is not in silent mode.)")
            
            HStack {
                Button("Play") {
                    synthesizer.speak(utterance)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Example 2: Utterance \"Knock Knock\"")
    }
}

#Preview {
    Example2View()
}
