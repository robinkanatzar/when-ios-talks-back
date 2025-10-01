import SwiftUI
import AVFoundation
import Speech
import Combine

// MARK: - ViewModel

final class Example9ViewModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // Outgoing speech
    private let synthesizer = AVSpeechSynthesizer()

    // Incoming speech (ASR)
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    // State for orchestration
    private enum ListenTarget { case none, whosThere, nobelWho }
    private struct Step {
        let text: String
        let voice: AVSpeechSynthesisVoice?
        let listenTarget: ListenTarget
    }

    private var steps: [Step] = []
    private var currentStepIndex: Int = 0
    private var currentListenTarget: ListenTarget = .none
    private var latestHeardPartial: String = ""

    // UI state
    @Published var permissionsGranted = false
    @Published var isRunning = false
    @Published var heardWhosThere: String = "—"
    @Published var heardNobelWho: String = "—"
    @Published var errorMessage: String?

    // Voices
    private let maleVoice: AVSpeechSynthesisVoice?
    private let femaleVoice: AVSpeechSynthesisVoice?

    override init() {
        // Try to pick recognizable male/female voices if installed; fall back to language default.
        func pickVoice(preferredNames: [String], language: String = "en-US") -> AVSpeechSynthesisVoice? {
            let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
            for name in preferredNames {
                if let v = voices.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
                    return v
                }
            }
            return AVSpeechSynthesisVoice(language: language)
        }

        self.maleVoice   = pickVoice(preferredNames: ["Alex", "Daniel", "Fred", "Aaron"])
        self.femaleVoice = pickVoice(preferredNames: ["Samantha", "Karen", "Tessa", "Victoria"])

        super.init()
        synthesizer.delegate = self

        // Pre-build the script
        steps = [
            Step(text: "Knock knock.",              voice: maleVoice,   listenTarget: .none),
            Step(text: "Who's there?",              voice: femaleVoice, listenTarget: .whosThere),
            Step(text: "Nobel.",                    voice: maleVoice,   listenTarget: .none),
            Step(text: "Nobel who?",                voice: femaleVoice, listenTarget: .nobelWho),
            Step(text: "No bell, that's why I knocked!", voice: maleVoice, listenTarget: .none),
        ]
    }

    // MARK: - Permissions

    func requestPermissions() {
        errorMessage = nil
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioSession.sharedInstance().requestRecordPermission { micOK in
                DispatchQueue.main.async {
                    self.permissionsGranted = (status == .authorized) && micOK
                    if !self.permissionsGranted {
                        self.errorMessage = "Microphone or Speech permission not granted."
                    }
                }
            }
        }
    }

    // MARK: - Controls

    func start() {
        guard !isRunning else { return }
        guard permissionsGranted else {
            errorMessage = "Grant Microphone & Speech access to run the demo."
            return
        }
        guard speechRecognizer?.isAvailable == true else {
            errorMessage = "Speech recognizer not available for current locale."
            return
        }

        errorMessage = nil
        heardWhosThere = "—"
        heardNobelWho = "—"
        latestHeardPartial = ""
        currentStepIndex = 0

        do {
            try configureAudioSession()
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        isRunning = true
        speakCurrentStep()
    }

    func stop() {
        isRunning = false
        stopRecognition(commit: false)

        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit {
        stop()
    }

    // MARK: - Orchestration

    private func speakCurrentStep() {
        guard currentStepIndex < steps.count else {
            isRunning = false
            return
        }

        let step = steps[currentStepIndex]

        // Start recognition for the female lines so we "hear" what she says.
        if step.listenTarget != .none {
            startRecognition(for: step.listenTarget)
        } else {
            stopRecognition(commit: false)
        }

        let u = AVSpeechUtterance(string: step.text)
        u.voice = step.voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        u.pitchMultiplier = 1.0
        u.preUtteranceDelay = 0.1
        u.postUtteranceDelay = 0.0

        synthesizer.speak(u)
    }

    // Advance when an utterance finishes; if we were listening, commit what we heard.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Give ASR a brief moment to flush tail of audio, then stop & commit.
        let step = steps[currentStepIndex]
        if step.listenTarget != .none {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.stopRecognition(commit: true)
                self.advance()
            }
        } else {
            advance()
        }
    }

    private func advance() {
        currentStepIndex += 1
        if isRunning {
            // Small pacing gap between lines
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.speakCurrentStep()
            }
        }
    }

    // MARK: - Audio + ASR

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // measurement mode avoids echo cancellation that might suppress device TTS.
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.defaultToSpeaker, .allowBluetooth, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognition(for target: ListenTarget) {
        stopRecognition(commit: false)

        currentListenTarget = target
        latestHeardPartial = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "AudioEngine error: \(error.localizedDescription)"
            return
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                DispatchQueue.main.async {
                    self.latestHeardPartial = r.bestTranscription.formattedString
                }
            }
            // If it ends early for any reason, we'll commit whatever we have on stopRecognition.
            if error != nil || (result?.isFinal ?? false) {
                // nothing special; normal commit happens on stopRecognition()
            }
        }
    }

    private func stopRecognition(commit: Bool) {
        if commit {
            switch currentListenTarget {
            case .whosThere:
                heardWhosThere = latestHeardPartial.isEmpty ? "—" : latestHeardPartial
            case .nobelWho:
                heardNobelWho = latestHeardPartial.isEmpty ? "—" : latestHeardPartial
            case .none:
                break
            }
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }

        currentListenTarget = .none
        latestHeardPartial = ""
    }
}

// MARK: - View

struct Example9View: View {
    @StateObject private var vm = Example9ViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Example 9: Knock-Knock (Phone talks to itself)")
                .font(.title2).bold()

            GroupBox("What you’ll hear") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Man: “Knock knock.”", systemImage: "person")
                    Label("Woman: “Who’s there?”", systemImage: "person.fill")
                    Label("Man: “Nobel.”", systemImage: "person")
                    Label("Woman: “Nobel who?”", systemImage: "person.fill")
                    Label("Man: “No bell, that’s why I knocked!”", systemImage: "person")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Speech API heard") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("“Who’s there?” →").font(.callout).foregroundStyle(.secondary)
                        Text(vm.heardWhosThere).font(.body).bold()
                    }
                    HStack {
                        Text("“Nobel who?” →").font(.callout).foregroundStyle(.secondary)
                        Text(vm.heardNobelWho).font(.body).bold()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let err = vm.errorMessage {
                Text(err).foregroundColor(.red).font(.footnote)
            }

            HStack {
                Button(vm.permissionsGranted ? "Permissions OK" : "Request Permissions") {
                    vm.requestPermissions()
                }
                .buttonStyle(.bordered)

                Spacer()

                if vm.isRunning {
                    Button("Stop") { vm.stop() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Joke") { vm.start() }
                        .buttonStyle(.borderedProminent)
                }
            }

            Spacer()

            Text("Tip: Recognition quality may vary because echo cancellation can suppress the device’s own voice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    Example9View()
}
