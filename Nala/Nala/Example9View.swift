import SwiftUI
import AVFoundation
import Combine

private enum OutputMode: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case text = "Text"
    case both = "Audio + Text"

    var id: String { rawValue }
}

final class Example9Speaker: ObservableObject {
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

struct Example9View: View {
    @State private var mode: OutputMode = .audio
    @StateObject private var speaker = Example9Speaker()
    @State private var utterance = ""
    
    let jokes: [String] = [
        "Knock knock. Who's there? Boo. Boo who? Don't cry. It's just a joke!",
        "Knock knock. Who's there? Cow says. Cow says who? No, silly, cow says moooo!",
        "Knock knock. Who's there? Lettuce. Lettuce who? Lettuce in, it's cold out here!"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // Subtitle
                Text("The funniest application you've ever downloaded.")
                
                // Audio, Text, Audio + Text
                Picker("Output mode", selection: $mode) {
                    ForEach(OutputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Output mode")
                
                // Button
                HStack {
                    Button("Tell me a joke") {
                        utterance = jokes.randomElement() ?? ""
                        if mode == .audio || mode == .both {
                            speaker.speak(utterance)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }

                // Joke text
                if !utterance.isEmpty && (mode == .text || mode == .both) {
                    Text(utterance)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Example 9: Audio out options")
        }
    }
}

#Preview {
    KnockKnockJokeView()
}
