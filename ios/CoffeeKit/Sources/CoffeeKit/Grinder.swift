import Foundation

/// A grinder's setting scale, used to keep suggestions on real, reachable settings.
public struct Grinder: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var minSetting: Double
    public var maxSetting: Double
    public var step: Double
    /// What one step is called on this grinder ("click", "setting").
    public var stepName: String

    public init(id: String, name: String, minSetting: Double, maxSetting: Double, step: Double, stepName: String) {
        self.id = id
        self.name = name
        self.minSetting = minSetting
        self.maxSetting = maxSetting
        self.step = step
        self.stepName = stepName
    }

    public var range: ClosedRange<Double> { minSetting...maxSetting }

    /// Snaps a value onto the grinder's scale.
    public func clamp(_ value: Double) -> Double {
        let snapped = ((value - minSetting) / step).rounded() * step + minSetting
        return min(max(snapped, minSetting), maxSetting)
    }

    /// Moves `steps` steps from `setting`; negative is finer. Returns nil if already at the end.
    public func move(_ setting: Double, steps: Double) -> Double? {
        let target = clamp(setting + steps * step)
        return target == clamp(setting) ? nil : target
    }

    /// "1 click" / "2 clicks".
    public func describe(steps: Double) -> String {
        let n = abs(steps)
        return "\(Format.number(n)) \(stepName)\(n == 1 ? "" : "s")"
    }

    public static let baratzaEncore = Grinder(id: "baratza-encore", name: "Baratza Encore", minSetting: 1, maxSetting: 40, step: 1, stepName: "click")
    public static let baratzaEncoreESP = Grinder(id: "baratza-encore-esp", name: "Baratza Encore ESP", minSetting: 1, maxSetting: 40, step: 1, stepName: "click")
    public static let comandante = Grinder(id: "comandante-c40", name: "Comandante C40", minSetting: 0, maxSetting: 40, step: 1, stepName: "click")
    public static let nicheZero = Grinder(id: "niche-zero", name: "Niche Zero", minSetting: 0, maxSetting: 50, step: 1, stepName: "step")
    public static let generic = Grinder(id: "generic", name: "Other grinder (1–40)", minSetting: 1, maxSetting: 40, step: 1, stepName: "step")

    public static let presets: [Grinder] = [.baratzaEncore, .baratzaEncoreESP, .comandante, .nicheZero, .generic]

    public static func preset(id: String) -> Grinder {
        presets.first { $0.id == id } ?? .baratzaEncore
    }
}
