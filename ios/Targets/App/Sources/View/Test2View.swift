//
//  Test2View.swift
//  Joke
//
//  Created by Robin Kanatzar on 9/11/25.
//

import SwiftUI
import AVFoundation

final class Speaker2: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()

        synthesizer.delegate = self
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }

    func stop(immediately: Bool = false) {
        _ = synthesizer.stopSpeaking(at: immediately ? .immediate : .word)
    }
}

struct Test2View: View {
    @State private var speaker = Speaker2()

        var body: some View {
            VStack(spacing: 16) {
        
                Text(".duckOthers")
                Button("Speak with AVSpeechSynthesizer") {
                    speaker.speak("Hello! I can talk on my own using AVSpeechSynthesizer. This is an extremely long test so I can use VoiceOver at the same time and see what happens. Blah blah blah. Testing testing 1, 2, 3.")
                }
                Button("Stop AVSpeechSynthesizer") {
                    speaker.stop()
                }
            }
            .padding()
        }
}

#Preview {
    Test2View()
}
