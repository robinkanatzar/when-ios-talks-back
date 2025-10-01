//
//  SelfTalkView.swift
//  Joke
//
//  Created by Robin Kanatzar on 9/24/25.
//

import SwiftUI
import AVFoundation
import Speech
import Combine

final class SelfTalkViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // Speech Out (TTS)
    private let synthesizer = AVSpeechSynthesizer()

    // Speech In (ASR)
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // UI state
    @Published var permissionsGranted = false
    @Published var isRunning = false
    @Published var inputText = "Hello from your phone. This is a self-talk demo."
    @Published var transcript = ""
    @Published var showPermissionAlert = false
    @Published var errorMessage: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Permissions
    func requestPermissions() {
        // Ask both at once: speech + microphone
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioSession.sharedInstance().requestRecordPermission { mic in
                DispatchQueue.main.async {
                    self.permissionsGranted = (status == .authorized) && mic
                    if !self.permissionsGranted {
                        self.showPermissionAlert = true
                    }
                }
            }
        }
    }

    // MARK: - Run demo
    func start() {
        guard !isRunning else { return }
        guard permissionsGranted else {
            showPermissionAlert = true
            return
        }

        transcript = ""
        errorMessage = nil

        do {
            try configureAudioSession()
            try startRecognition()
            speakNow()
            isRunning = true
        } catch {
            errorMessage = "Could not start: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        isRunning = false

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Internals
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Play + record so we can speak and listen at the same time.
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, when in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                DispatchQueue.main.async {
                    self.transcript = r.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async { self.isRunning = false }
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }

    private func speakNow() {
        let utterance = AVSpeechUtterance(string: inputText)
        // Tune as you like:
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.0
        // Choose a specific voice if desired:
        // utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate (optional)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // You could update UI here if needed.
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // If you want to stop recognition after speaking once, uncomment:
        // stop()
    }

    deinit {
        stop()
    }
}

struct SelfTalkView: View {
    @StateObject private var vm = SelfTalkViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Self-Talk Demo")
                .font(.title2).bold()

            TextField("Text to speak…", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .padding(.horizontal)

            HStack {
                Button(vm.permissionsGranted ? "Permissions Granted" : "Request Permissions") {
                    vm.requestPermissions()
                }
                .buttonStyle(.bordered)

                Spacer()

                if vm.isRunning {
                    Button("Stop") { vm.stop() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Demo") { vm.start() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)

            GroupBox("Live Transcript") {
                ScrollView {
                    Text(vm.transcript.isEmpty ? "—" : vm.transcript)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                .frame(minHeight: 120, maxHeight: 240)
            }
            .padding(.horizontal)

            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).font(.footnote).padding(.horizontal)
            }

            Spacer()

            Text("Tip: Echo cancellation may suppress the phone’s own voice on some devices/rooms.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .multilineTextAlignment(.center)
        }
        .alert("Microphone & Speech permission required", isPresented: $vm.showPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable access in Settings if you previously denied it.")
        }
        .padding(.top, 24)
    }
}
