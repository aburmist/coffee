import Foundation

/// One concrete change to try on the next brew.
public struct DialInSuggestion: Hashable, Sendable {
    public enum Kind: String, Sendable {
        case keep, grindFiner, grindCoarser, hotter, cooler, longerRatio, shorterRatio, moreDose, addTaste
    }

    public var kind: Kind
    public var title: String
    public var reason: String
    /// The grind setting to use next, for grind suggestions.
    public var newGrindSetting: Double?
}

/// Extraction rules of thumb, applied to the last brew.
///
/// Sour, sharp or fast → extract more: grind finer, hotter water, or more water.
/// Bitter, harsh or slow → extract less: grind coarser, cooler water, or less water.
public enum DialIn {
    public static func suggestions(for brew: BrewRecord, grinder: Grinder, unit: TemperatureUnit = .fahrenheit) -> [DialInSuggestion] {
        let direction = extractionDirection(for: brew)
        guard let direction else {
            if let rating = brew.rating, rating >= 4 {
                return [keep(brew)]
            }
            return [DialInSuggestion(kind: .addTaste, title: "Say how it tasted",
                                     reason: "Mark it sour, balanced or bitter to get a suggestion for the next brew.")]
        }
        if direction == 0 { return [keep(brew)] }

        var result: [DialInSuggestion] = []
        let more = direction > 0
        let why = reason(for: brew, more: more)

        // 1. Grind is the main lever.
        if let setting = brew.grindSetting {
            let steps = brew.method.grindStepsPerAdjustment * (more ? -1 : 1)
            if let next = grinder.move(setting, steps: steps) {
                result.append(DialInSuggestion(
                    kind: more ? .grindFiner : .grindCoarser,
                    title: "Grind \(grinder.describe(steps: steps)) \(more ? "finer" : "coarser") → \(Format.number(next))",
                    reason: why, newGrindSetting: next))
            }
        } else {
            result.append(DialInSuggestion(kind: more ? .grindFiner : .grindCoarser,
                                           title: "Grind a little \(more ? "finer" : "coarser")", reason: why))
        }

        // 2. Ratio, for espresso: a short shot tastes sour, a long one bitter.
        if brew.method == .espresso, let ratio = brew.ratio, let dose = brew.doseGrams {
            if more, ratio < 1.8 {
                result.append(DialInSuggestion(kind: .longerRatio, title: "Pull a longer shot: \(Format.number((dose * 2).rounded())) g out",
                                               reason: "1:\(Format.number(ratio.rounded1)) is short; 1:2 extracts more."))
            } else if !more, ratio > 2.5 {
                result.append(DialInSuggestion(kind: .shorterRatio, title: "Stop the shot earlier: \(Format.number((dose * 2).rounded())) g out",
                                               reason: "1:\(Format.number(ratio.rounded1)) is long; 1:2 extracts less."))
            }
        }

        // 3. Temperature, as a second lever.
        if let temp = brew.temperatureC, brew.method != .moka, brew.method != .coldBrew {
            let change: Double = unit == .fahrenheit ? 4 : 2
            let next = unit.toCelsius(unit.fromCelsius(temp) + (more ? change : -change))
            if more, temp < 96 {
                result.append(DialInSuggestion(kind: .hotter, title: "Or use hotter water: \(unit.format(celsius: next))",
                                               reason: "Hotter water extracts more."))
            } else if !more, temp > 85 {
                result.append(DialInSuggestion(kind: .cooler, title: "Or use cooler water: \(unit.format(celsius: next))",
                                               reason: "Cooler water extracts less."))
            }
        }
        return result
    }

    /// +1 = extract more, -1 = extract less, 0 = dialed in, nil = unknown.
    static func extractionDirection(for brew: BrewRecord) -> Int? {
        switch brew.extraction {
        case .sour: return 1
        case .bitter: return -1
        case .balanced: return 0
        case nil: break
        }
        // No taste given: fall back on brew time when we know the target window.
        if let time = brew.timeSeconds, let window = brew.method.targetTimeWindow, brew.method == .espresso {
            if time < window.lowerBound { return 1 }
            if time > window.upperBound { return -1 }
        }
        return nil
    }

    static func reason(for brew: BrewRecord, more: Bool) -> String {
        var parts: [String] = []
        if let e = brew.extraction { parts.append(e == .sour ? "Sour means under-extracted" : "Bitter means over-extracted") }
        if let time = brew.timeSeconds, let window = brew.method.targetTimeWindow {
            if time < window.lowerBound {
                parts.append("\(Format.duration(time)) is fast for \(brew.method.rawValue) (\(Format.duration(window.lowerBound))–\(Format.duration(window.upperBound)))")
            } else if time > window.upperBound {
                parts.append("\(Format.duration(time)) is slow for \(brew.method.rawValue) (\(Format.duration(window.lowerBound))–\(Format.duration(window.upperBound)))")
            }
        }
        if parts.isEmpty { return more ? "Extract a bit more." : "Extract a bit less." }
        return parts.joined(separator: "; ") + "."
    }

    static func keep(_ brew: BrewRecord) -> DialInSuggestion {
        DialInSuggestion(kind: .keep, title: "Dialed in — repeat this recipe",
                         reason: brew.grindSetting.map { "Keep grind at \(Format.number($0))." } ?? "Keep everything the same.")
    }

    /// The best-rated brew, newest first among ties. Used as "best recipe so far" for a bean.
    public static func best(of brews: [BrewRecord]) -> BrewRecord? {
        brews.filter { $0.rating != nil }.max { a, b in
            (a.rating!, a.date) < (b.rating!, b.date)
        }
    }
}

extension Double {
    var rounded1: Double { (self * 10).rounded() / 10 }
}
