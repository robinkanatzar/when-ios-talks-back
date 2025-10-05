import SwiftUI
import AVFoundation
import Combine

private enum OutputMode: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case text = "Text"
    case both = "Audio + Text"

    var id: String { rawValue }
}

// MARK: - Speaker

final class FinalDemoSpeaker: ObservableObject {
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

// MARK: - Chat Models

private enum ChatRole: String {
    case phone = "Phone"
    case user = "You"
}

private struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ChatRole
    var text: String            // <- make mutable so we can stream words
    let timestamp = Date()
}

// MARK: - Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    var isPhone: Bool { message.role == .phone }

    var body: some View {
        HStack {
            if isPhone {
                // Phone on the left
                bubble
                Spacer(minLength: 32)
            } else {
                // User on the right
                Spacer(minLength: 32)
                bubble
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role.rawValue) says \(message.text)")
    }

    private var bubble: some View {
        VStack(alignment: isPhone ? .leading : .trailing, spacing: 4) {
            Text(message.text)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(isPhone ? Color(.systemGray6) : Color.accentColor.opacity(0.15))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - View

struct FinalDemoView: View {
    @State private var mode: OutputMode = .both
    @StateObject private var speaker = FinalDemoSpeaker()

    // Keeps your original single-line output if you want it
    @State private var utterance = ""

    // Chat state
    @State private var messages: [ChatMessage] = []
    @State private var isRunningScriptedJoke = false

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

                // Buttons
                HStack(spacing: 12) {
                    Button("Tell me a joke") {
                        runScriptedKnockKnock()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunningScriptedJoke)
                }

                // Optional original joke text
                if !utterance.isEmpty && (mode == .text || mode == .both) {
                    Text(utterance)
                        .padding(.top, 4)
                }

                // Chat transcript
                if !messages.isEmpty {
                    Divider().padding(.vertical, 6)

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(messages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .onChange(of: messages) { _, _ in
                            // Scroll to bottom when new messages come in
                            if let lastID = messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Knock Knock Jokes")
        }
    }

    // MARK: - Scripted sequence with delays
    private func runScriptedKnockKnock() {
        guard !isRunningScriptedJoke else { return }
        isRunningScriptedJoke = true
        messages.removeAll()

        Task { @MainActor in
            func addPhone(_ text: String) {
                messages.append(.init(role: .phone, text: text))
                if mode == .audio || mode == .both {
                    speaker.speak(text)
                }
            }

            // Phone: "Knock knock"
            addPhone("Knock knock")
            try? await Task.sleep(for: .seconds(4.0))

            // User: stream "Who's there?"
            await streamUserLine("Who's there?", perWordDelay: 0.45)
            try? await Task.sleep(for: .seconds(1.0))

            // Phone: "Lettuce"
            addPhone("Lettuce")
            try? await Task.sleep(for: .seconds(2.0))

            // User: stream "Lettuce who?"
            await streamUserLine("Lettuce who?", perWordDelay: 0.45)
            try? await Task.sleep(for: .seconds(0.8))

            // Phone: punchline
            addPhone("Lettuce in, it's cold outside.")
            isRunningScriptedJoke = false
        }
    }

    /// Streams a user's line word-by-word to imitate live speech transcription.
    @MainActor
    private func streamUserLine(_ fullText: String, perWordDelay: Double = 0.4) async {
        // Start with an empty user message we will gradually fill
        var msg = ChatMessage(role: .user, text: "")
        messages.append(msg)
        let id = msg.id

        // Split on spaces to preserve punctuation attached to words
        let words = fullText.split(separator: " ").map(String.init)

        var current = ""
        for (idx, word) in words.enumerated() {
            current += idx == 0 ? word : " \(word)"
            if let i = messages.firstIndex(where: { $0.id == id }) {
                messages[i].text = current
            }
            try? await Task.sleep(for: .seconds(perWordDelay))
        }
    }
}

#Preview {
    FinalDemoView()
}
