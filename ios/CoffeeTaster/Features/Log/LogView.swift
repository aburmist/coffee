import CoffeeKit
import SwiftData
import SwiftUI

/// Describe a brew in your own words (typed or spoken); the app fills in the rest.
struct LogView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @Query(sort: \Brew.date, order: .reverse) private var recent: [Brew]

    @State private var text = ""
    @State private var base: LogBase?
    @State private var speech = SpeechRecognizer()
    @State private var isWorking = false
    @State private var editor: EditorRequest?
    @FocusState private var focused: Bool

    struct EditorRequest: Identifiable {
        let id = UUID()
        let form: BrewForm
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let base {
                        HStack {
                            Label("Starting from \(base.label)", systemImage: "arrow.uturn.backward.circle")
                                .font(.subheadline)
                            Spacer()
                            Button("Clear", systemImage: "xmark.circle.fill") { self.base = nil }
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .focused($focused)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        if text.isEmpty {
                            Text(placeholder)
                                .foregroundStyle(.tertiary)
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task { await speech.toggle() }
                        } label: {
                            Label(speech.isRecording ? "Stop" : "Speak",
                                  systemImage: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(speech.isRecording ? .red : .accentColor)
                        .controlSize(.large)

                        Button {
                            Task { await fillIn() }
                        } label: {
                            Group {
                                if isWorking { ProgressView() } else { Label("Fill in", systemImage: "sparkles") }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isWorking || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && base == nil))
                    }

                    if let error = speech.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }

                    if let last = recent.first {
                        Button {
                            base = LogBase(label: "your last \(last.method.rawValue)", draft: BrewDraft(recipeOf: last.record))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Same as last time", systemImage: "arrow.counterclockwise")
                                Text("\(last.title) · \(last.recipeLine)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button("Enter manually", systemImage: "square.and.pencil") {
                        openEditor(draft: base?.draft ?? BrewDraft(), bean: nil, filled: [])
                    }
                    .buttonStyle(.borderless)

                    Text(BrewExtractor.availabilityText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Tip: say “Hey Siri, log a coffee in Coffee Taster” to log without opening the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Log a Brew")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
            .onChange(of: speech.transcript) { _, new in
                if !new.isEmpty { text = new }
            }
            .onChange(of: router.pendingBase, initial: true) { _, new in
                guard let new else { return }
                base = new
                router.pendingBase = nil
            }
            .sheet(item: $editor) { request in
                BrewEditorView(form: request.form) {
                    text = ""
                    base = nil
                }
            }
        }
    }

    private var placeholder: String {
        if base != nil { return "How did it taste? e.g. “a bit sour, bright, 3.5 stars”" }
        return "e.g. “Espresso, 18g in 36g out, 5 clicks, 28s, chocolatey but a bit sour, 4 stars”"
    }

    private func fillIn() async {
        focused = false
        speech.stop()
        isWorking = true
        defer { isWorking = false }
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await BrewLogger.understand(input, base: base?.draft, context: context)
        var filled = result.fromText.filledFields
        if result.bean != nil, !input.isEmpty { filled.insert("bean") }
        openEditor(draft: result.draft, bean: result.bean, filled: filled)
    }

    private func openEditor(draft: BrewDraft, bean: Bean?, filled: Set<String>) {
        let form = BrewForm(draft: draft, bean: bean, originalText: text.trimmingCharacters(in: .whitespacesAndNewlines), unit: unit, filled: filled)
        editor = EditorRequest(form: form)
    }
}
