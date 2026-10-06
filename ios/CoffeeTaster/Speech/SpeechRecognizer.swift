import AVFoundation
import Foundation
import Observation
import Speech

/// Live speech-to-text for the Log screen's mic button. Runs on the iPhone when supported.
@MainActor
@Observable
final class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() async {
        if isRecording { stop() } else { await start() }
    }

    func start() async {
        errorMessage = nil
        guard await Self.requestPermissions() else {
            errorMessage = "Allow microphone and speech recognition in Settings to dictate."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            request.addsPunctuation = true
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(for: request))
            audioEngine.prepare()
            try audioEngine.start()
            transcript = ""
            isRecording = true

            task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(for: self))
        } catch {
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        guard isRecording || audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // These closures run on audio and speech threads, so they are built outside
    // the main actor to avoid inheriting its isolation.
    nonisolated private static func tapBlock(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    nonisolated private static func resultHandler(for owner: SpeechRecognizer) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak owner] result, error in
            let text = result?.bestTranscription.formattedString
            let done = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                guard let owner else { return }
                if let text { owner.transcript = text }
                if done { owner.stop() }
            }
        }
    }

    nonisolated private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
