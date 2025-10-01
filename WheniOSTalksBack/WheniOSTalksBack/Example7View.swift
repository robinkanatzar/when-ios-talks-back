import SwiftUI
import AVFoundation
import Combine

final class Example7Speaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAudioSession()
        observeVoiceOverStatus()
        if UIAccessibility.isVoiceOverRunning {
            stop()
        }
    }
    
    private func observeVoiceOverStatus() {
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if UIAccessibility.isVoiceOverRunning {
                    self.stop()
                }
            }
            .store(in: &cancellables)
    }
    
    func speak(_ text: String) {
        guard !UIAccessibility.isVoiceOverRunning else { return }
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }
    
    func stop() {
        _ = synthesizer.stopSpeaking(at: .immediate)
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

struct Example7View: View {
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverOn
    @State private var showVoiceOverAlert = false
    @StateObject private var speaker = Example7Speaker()
    
    let utterance = "Knock knock. Who's there? Cow says. Cow says who? No, silly, cow says moooo!"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Press the button and hear AVSpeechSynthesizer tell you a joke while you turn on VoiceOver on and off.")
            Text("When VoiceOver is on, AVSpeechSynthesizer will not speak.")
            Text("When the user turns on VoiceOver while AVSpeechSynthesizer is speaking, AVSpeechSynthesizer will stop immediately.")
            Text("When VoiceOver is off, AVSpeechSynthesizer will speak.")
            Text("(Make sure your phone is not in silent mode.)")
            
            HStack {
                Button("Play") {
                    if isVoiceOverOn {
                        showVoiceOverAlert = true
                    } else {
                        speaker.speak(utterance)
                    }
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            
            Spacer()
            
            Text("VoiceOver is \(isVoiceOverOn ? "ON" : "OFF")")
        }
        .padding()
        .navigationTitle("Example 7: Joke When VoiceOver Off")
        .alert("VoiceOver is on, so I will not tell you a joke with AVSpeechSynthesizer. Turn VoiceOver off and try again.",
               isPresented: $showVoiceOverAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

#Preview {
    Example7View()
}
