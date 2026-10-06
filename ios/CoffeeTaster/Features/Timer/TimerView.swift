import CoffeeKit
import SwiftData
import SwiftUI

struct TimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @State private var timer = BrewTimer()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Method", selection: $timer.method) {
                        ForEach(BrewMethod.allCases) { Label($0.rawValue, systemImage: $0.symbolName).tag($0) }
                    }
                    Stepper(value: $timer.dose, in: 5...200, step: 0.5) {
                        LabeledContent("Coffee", value: "\(Format.number(timer.dose)) g")
                    }
                    Stepper(value: $timer.ratio, in: 1...20, step: timer.method == .espresso ? 0.1 : 0.5) {
                        LabeledContent("Ratio", value: "1:\(Format.number((timer.ratio * 10).rounded() / 10))")
                    }
                    LabeledContent(timer.method.usesYield ? "Espresso out" : "Water", value: "\(Format.number(timer.recipe.outputGrams)) g")
                    if let t = timer.recipe.temperatureC {
                        LabeledContent("Water temperature", value: unit.format(celsius: t))
                    }
                } header: {
                    Text(timer.recipe.name)
                }
                .disabled(timer.isRunning)

                Section {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        let elapsed = timer.elapsed(at: context.date)
                        VStack(spacing: 8) {
                            Text(Format.duration(Int(elapsed)))
                                .font(.system(size: 72, weight: .semibold, design: .rounded).monospacedDigit())
                                .contentTransition(.numericText())
                            if timer.isRunning, let next = timer.recipe.secondsToNextStep(at: elapsed) {
                                Text("Next step in \(Int(next.rounded(.up))) s")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            } else if timer.recipe.totalSeconds > 0, !timer.isFinished {
                                Text("Target \(Format.duration(timer.recipe.totalSeconds))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    controls
                }

                Section("Steps") {
                    ForEach(Array(timer.recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top) {
                            Text(Format.duration(step.startsAt))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 44, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.headline)
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let g = step.targetGrams {
                                Text("\(Format.number(g)) g").font(.subheadline.monospacedDigit())
                            }
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(timer.isRunning && index == timer.stepIndex ? Color.accentColor.opacity(0.18) : nil)
                    }
                }
            }
            .navigationTitle("Brew Timer")
            .sensoryFeedback(.impact(weight: .heavy), trigger: timer.stepIndex)
            .sensoryFeedback(.success, trigger: timer.isFinished) { _, finished in finished }
            .onChange(of: router.pendingTimerMethod, initial: true) { _, method in
                guard let method else { return }
                if !timer.isRunning {
                    timer.reset()
                    timer.method = method
                    if let dose = router.pendingTimerDose { timer.dose = dose }
                    timer.start()
                }
                router.pendingTimerMethod = nil
                router.pendingTimerDose = nil
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        if timer.isRunning {
            Button {
                withAnimation { timer.stop() }
            } label: {
                Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        } else if timer.isFinished {
            Button {
                let grind = DataStore.lastBrew(context, method: timer.method)?.grindSetting
                router.log(from: LogBase(label: "the timer (\(timer.method.rawValue), \(Format.duration(Int(timer.elapsed()))))",
                                         draft: timer.draft(grindFromLast: grind)))
                timer.reset()
            } label: {
                Label("Log this brew", systemImage: "square.and.pencil").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Reset", role: .destructive) { timer.reset() }
                .frame(maxWidth: .infinity)
        } else {
            Button {
                withAnimation { timer.start() }
            } label: {
                Label("Start", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
