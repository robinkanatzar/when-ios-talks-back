////
////  SpeechRecognizer.swift
////  Joke
////
////  Created by Robin Kanatzar on 7/17/25.
////
///

import Foundation
import Speech
import AVFoundation

class SimpleSpeechRecognizer: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    @Published var transcript: String = ""

    override init() {
        super.init()
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition not authorized")
            }
        }
    }

    func startListening() {
        // Reset session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session for recording: \(error)")
            return
        }

        transcript = ""
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0) // safety
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        task = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }


    func stopListening() {
        audioEngine.stop()
        audioEngine.reset()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        // ✅ Reset audio session to fix quiet/muffled utterance
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to reset audio session: \(error)")
        }
    }

}

