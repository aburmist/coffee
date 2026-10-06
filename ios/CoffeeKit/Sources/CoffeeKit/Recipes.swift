import Foundation

public struct RecipeStep: Hashable, Sendable, Identifiable {
    public var title: String
    public var detail: String
    /// Seconds from the start of the brew.
    public var startsAt: Int
    /// Scale reading to reach during this step, if any.
    public var targetGrams: Double?

    public var id: Int { startsAt }

    public init(_ title: String, _ detail: String, at startsAt: Int, target: Double? = nil) {
        self.title = title
        self.detail = detail
        self.startsAt = startsAt
        self.targetGrams = target
    }
}

/// A timed brew recipe, scaled to a dose and ratio.
public struct Recipe: Hashable, Sendable {
    public var method: BrewMethod
    public var name: String
    public var doseGrams: Double
    public var ratio: Double
    public var temperatureC: Double?
    public var steps: [RecipeStep]
    /// When the brew should be finished, in seconds.
    public var totalSeconds: Int

    /// Water in for filter methods, drink weight for espresso.
    public var outputGrams: Double { (doseGrams * ratio).rounded() }

    /// The step running at `elapsed` seconds.
    public func stepIndex(at elapsed: TimeInterval) -> Int {
        steps.lastIndex { TimeInterval($0.startsAt) <= elapsed } ?? 0
    }

    /// Seconds until the next step starts, or nil during the last step.
    public func secondsToNextStep(at elapsed: TimeInterval) -> TimeInterval? {
        let i = stepIndex(at: elapsed)
        guard i + 1 < steps.count else { return nil }
        return TimeInterval(steps[i + 1].startsAt) - elapsed
    }
}

public enum RecipeLibrary {
    public static func recipe(for method: BrewMethod, doseGrams: Double? = nil, ratio: Double? = nil, temperatureC: Double? = nil) -> Recipe {
        let dose = doseGrams ?? method.defaultDoseGrams
        let ratio = ratio ?? method.defaultRatio
        let out = (dose * ratio).rounded()
        func g(_ fraction: Double) -> Double { (out * fraction).rounded() }
        let temp = temperatureC ?? method.defaultTemperatureC

        let name: String
        let steps: [RecipeStep]
        let total: Int
        switch method {
        case .espresso:
            name = "Classic 1:\(Format.number(ratio)) shot"
            steps = [
                RecipeStep("Pre-infusion", "Start the shot; first drops in 5–8 s", at: 0),
                RecipeStep("Extract", "Stop at \(Format.number(out)) g in the cup", at: 6, target: out),
                RecipeStep("Done", "Aim for 25–32 s total", at: 28, target: out),
            ]
            total = 28
        case .pourOver:
            name = "Three-pour V60"
            let bloom = (dose * 2.5).rounded()
            steps = [
                RecipeStep("Bloom", "Pour \(Format.number(bloom)) g, swirl gently", at: 0, target: bloom),
                RecipeStep("First pour", "Pour slowly to \(Format.number(g(0.6))) g", at: 45, target: g(0.6)),
                RecipeStep("Second pour", "Pour to \(Format.number(out)) g", at: 75, target: out),
                RecipeStep("Drawdown", "Swirl once, let it drain", at: 105, target: out),
                RecipeStep("Done", "Aim to finish around 3:00", at: 180, target: out),
            ]
            total = 180
        case .aeroPress:
            name = "Standard AeroPress"
            steps = [
                RecipeStep("Pour", "Pour all \(Format.number(out)) g of water", at: 0, target: out),
                RecipeStep("Stir", "Stir 3 times, put the plunger on", at: 10, target: out),
                RecipeStep("Steep", "Wait", at: 20, target: out),
                RecipeStep("Press", "Press gently for about 30 s", at: 90, target: out),
                RecipeStep("Done", "Stop at the hiss", at: 120, target: out),
            ]
            total = 120
        case .frenchPress:
            name = "Hoffmann French press"
            steps = [
                RecipeStep("Pour", "Pour all \(Format.number(out)) g of water", at: 0, target: out),
                RecipeStep("Steep", "Leave it, don't stir", at: 15, target: out),
                RecipeStep("Break the crust", "Stir the top, skim off the foam", at: 240, target: out),
                RecipeStep("Settle", "Put the lid on, plunger just at the surface", at: 270, target: out),
                RecipeStep("Pour", "Pour slowly without pressing down", at: 300, target: out),
            ]
            total = 300
        case .clever:
            name = "Clever steep and drain"
            steps = [
                RecipeStep("Pour", "Pour all \(Format.number(out)) g of water", at: 0, target: out),
                RecipeStep("Steep", "Lid on", at: 20, target: out),
                RecipeStep("Stir", "Stir gently 3 times", at: 120, target: out),
                RecipeStep("Drain", "Set it on the cup", at: 150, target: out),
                RecipeStep("Done", "Aim to finish around 3:30", at: 210, target: out),
            ]
            total = 210
        case .moka:
            name = "Moka pot"
            steps = [
                RecipeStep("Heat", "Medium heat, lid open", at: 0),
                RecipeStep("Watch the flow", "Turn the heat down when coffee appears", at: 180),
                RecipeStep("Stop", "Off the heat at the first sputter; cool the base", at: 270),
            ]
            total = 270
        case .drip, .coldBrew, .other:
            name = "\(method.rawValue) timer"
            steps = [RecipeStep("Brewing", "\(Format.number(dose)) g coffee · \(Format.number(out)) g water", at: 0, target: out)]
            total = method == .drip ? 300 : 0
        }
        return Recipe(method: method, name: name, doseGrams: dose, ratio: ratio, temperatureC: temp, steps: steps, totalSeconds: total)
    }
}
