import ActivityKit
import CoffeeKit
import Foundation
import Observation

/// The running brew timer: which step you're on, haptics and the Live Activity.
@MainActor
@Observable
final class BrewTimer {
    var method: BrewMethod = AppSettings.defaultMethod {
        didSet { if !isRunning { ratio = method.defaultRatio; dose = method.defaultDoseGrams } }
    }
    var dose: Double = AppSettings.defaultMethod.defaultDoseGrams
    var ratio: Double = AppSettings.defaultMethod.defaultRatio

    private(set) var startDate: Date?
    private(set) var stoppedAt: TimeInterval?
    private(set) var stepIndex = 0

    private var ticker: Task<Void, Never>?
    private var activity: Activity<BrewTimerAttributes>?

    var isRunning: Bool { startDate != nil && stoppedAt == nil }
    var isFinished: Bool { stoppedAt != nil }

    var recipe: Recipe {
        RecipeLibrary.recipe(for: method, doseGrams: dose, ratio: ratio)
    }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        if let stoppedAt { return stoppedAt }
        guard let startDate else { return 0 }
        return now.timeIntervalSince(startDate)
    }

    func start() {
        reset()
        let now = Date()
        startDate = now
        stepIndex = 0
        startActivity(at: now)
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        stoppedAt = elapsed()
        ticker?.cancel()
        ticker = nil
        endActivity()
    }

    func reset() {
        ticker?.cancel()
        ticker = nil
        startDate = nil
        stoppedAt = nil
        stepIndex = 0
        endActivity()
    }

    /// A draft for the Log screen: the recipe as brewed, with the measured time.
    func draft(grindFromLast grind: Double?) -> BrewDraft {
        var d = BrewDraft()
        d.method = method
        d.doseGrams = dose
        if method.usesYield { d.yieldGrams = recipe.outputGrams } else { d.waterGrams = recipe.outputGrams }
        d.temperatureC = recipe.temperatureC
        d.timeSeconds = Int(elapsed().rounded())
        d.grindSetting = grind
        return d
    }

    private func tick() {
        guard isRunning else { return }
        let index = recipe.stepIndex(at: elapsed())
        if index != stepIndex {
            stepIndex = index
            updateActivity()
        }
    }

    // MARK: - Live Activity

    private func state(finished: Bool = false) -> BrewTimerAttributes.ContentState {
        let r = recipe
        let step = r.steps[min(stepIndex, r.steps.count - 1)]
        let start = startDate ?? Date()
        let next = stepIndex + 1 < r.steps.count ? start.addingTimeInterval(TimeInterval(r.steps[stepIndex + 1].startsAt)) : nil
        return BrewTimerAttributes.ContentState(
            stepTitle: step.title, stepDetail: step.detail,
            target: step.targetGrams.map { "\(Format.number($0)) g" },
            startedAt: start, nextStepAt: next, isFinished: finished)
    }

    private func startActivity(at date: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let r = recipe
        let attributes = BrewTimerAttributes(
            methodName: method.rawValue, symbolName: method.symbolName,
            summary: "\(Format.number(dose)) g → \(Format.number(r.outputGrams)) g · 1:\(Format.number(ratio))")
        activity = try? Activity.request(attributes: attributes, content: ActivityContent(state: state(), staleDate: nil))
    }

    private func updateActivity() {
        guard let activity else { return }
        let content = ActivityContent(state: state(), staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endActivity() {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: state(finished: true), staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60))) }
    }
}
