import Foundation

/// Rule-based extraction of a brew from free text.
///
/// The app prefers Apple's on-device model, which understands much looser phrasing.
/// This parser is the fallback when the model isn't available, and it backs the model
/// up on precise numbers ("18g", "3:10", "200°F") where rules are reliable.
public enum BrewTextParser {
    public static func parse(_ text: String) -> BrewDraft {
        var d = BrewDraft()
        let t = text.lowercased()
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "º", with: "°")

        d.method = BrewMethod(lenient: t)
        d.grindSetting = grind(in: t)
        d.temperatureC = temperature(in: t)
        d.timeSeconds = time(in: t)
        d.rating = rating(in: text)
        d.extraction = extraction(in: t)
        d.flavors = Flavors.find(in: t)
        assignGrams(in: t, to: &d)

        if let ratio = ratio(in: t), let dose = d.doseGrams {
            if d.method == .espresso, d.yieldGrams == nil {
                d.yieldGrams = (dose * ratio).rounded()
            } else if d.method != .espresso, d.waterGrams == nil {
                d.waterGrams = (dose * ratio).rounded()
            }
        }
        d.comment = comment(in: text)
        return d.sanitized()
    }

    // MARK: - Fields

    static func grind(in t: String) -> Double? {
        if let m = t.firstMatch(of: #/(?:grind(?:\s+(?:size|setting))?|size|setting|click|step)\s*(?:of|at|on|:|=|#)?\s*(\d+(?:[.,]\d+)?)/#) {
            return Parse.number(String(m.1))
        }
        if let m = t.firstMatch(of: #/(\d+(?:[.,]\d+)?)\s*(?:clicks?|steps?)\b/#) {
            return Parse.number(String(m.1))
        }
        return nil
    }

    static func temperature(in t: String) -> Double? {
        if let m = t.firstMatch(of: #/(\d{2,3}(?:[.,]\d)?)\s*(?:°|deg(?:rees?)?)?\s*([cf])\b/#),
           let v = Parse.number(String(m.1)) {
            return m.2 == "f" ? TemperatureUnit.fahrenheit.toCelsius(v) : v
        }
        if let m = t.firstMatch(of: #/(\d{2,3}(?:[.,]\d)?)\s*(?:°|degrees?)/#), let v = Parse.number(String(m.1)) {
            // No unit: water above 110 can't be °C, so it must be °F.
            return v > 110 ? TemperatureUnit.fahrenheit.toCelsius(v) : v
        }
        if t.contains(#/\bboil(?:ing|ed)?\b/#) || t.contains("off the boil") {
            return 100
        }
        return nil
    }

    static func time(in t: String) -> Int? {
        for m in t.matches(of: #/(\d{1,2}):(\d{2})\b/#) {
            // "ratio 1:16" is a ratio, not a time.
            let before = t[..<m.range.lowerBound].suffix(8)
            if before.contains("ratio") { continue }
            return Int(m.1)! * 60 + Int(m.2)!
        }
        if let m = t.firstMatch(of: #/(\d+(?:[.,]\d+)?)\s*(?:m|min|mins|minutes?)\b\s*(?:and\s*)?(?:(\d+)\s*(?:s|sec|secs|seconds?)\b)?/#),
           let minutes = Parse.number(String(m.1)) {
            return Int((minutes * 60).rounded()) + (m.2.flatMap { Int($0) } ?? 0)
        }
        if let m = t.firstMatch(of: #/(\d+)\s*(?:s|sec|secs|seconds?)\b/#) {
            return Int(m.1)
        }
        return nil
    }

    static func ratio(in t: String) -> Double? {
        if let m = t.firstMatch(of: #/ratio\s*(?:of|is|:)?\s*1\s*[:/]\s*(\d+(?:[.,]\d+)?)/#) {
            return Parse.number(String(m.1))
        }
        // "1:2" or "1:2.5" (a single digit after the colon can't be a time).
        if let m = t.firstMatch(of: #/\b1\s*:\s*(\d(?:[.,]\d+)?)(?!\d)/#) {
            return Parse.number(String(m.1))
        }
        return nil
    }

    static func rating(in text: String) -> Double? {
        let t = text.lowercased()
        if let m = t.firstMatch(of: #/(\d(?:[.,]5)?)\s*(?:\/\s*5|stars?|★|out of 5)/#) {
            return Parse.number(String(m.1))
        }
        let stars = text.filter { $0 == "⭐" || $0 == "★" }.count
        if stars > 0 { return Double(min(stars, 5)) }
        return nil
    }

    static func extraction(in t: String) -> Extraction? {
        func mentioned(_ words: [String]) -> Bool {
            words.contains { word in
                t.ranges(of: word).contains { range in
                    let before = t[..<range.lowerBound].suffix(5)
                    return !(before.hasSuffix("not ") || before.hasSuffix("no ") || before.hasSuffix("n't "))
                }
            }
        }
        let sour = mentioned(["sour", "under-extracted", "underextracted", "under extracted", "tart", "salty"])
        let bitter = mentioned(["bitter", "over-extracted", "overextracted", "over extracted", "harsh", "astringent", "burnt", "ashy"])
        switch (sour, bitter) {
        case (true, false): return .sour
        case (false, true): return .bitter
        case (true, true): return nil
        default:
            return mentioned(["balanced", "dialed in", "dialled in", "perfect", "spot on"]) ? .balanced : nil
        }
    }

    /// Gram amounts: "18g in, 36g out", "18g coffee", "300g water", or just "18g … 300g".
    static func assignGrams(in t: String, to d: inout BrewDraft) {
        var unlabeled: [Double] = []
        for m in t.matches(of: #/(\d+(?:[.,]\d+)?)\s*(?:g|gr|grams?)\b/#) {
            guard let value = Parse.number(String(m.1)) else { continue }
            let after = t[m.range.upperBound...].prefix(12)
            let before = t[..<m.range.lowerBound].suffix(12)
            if after.contains(#/^\s*(?:in\b|of (?:coffee|beans)|coffee|beans|dose)/#) || before.contains(#/(?:dose|coffee|beans)\s*(?:of|:)?\s*$/#) {
                d.doseGrams = d.doseGrams ?? value
            } else if after.contains(#/^\s*(?:out\b|yield|in the cup|espresso)/#) || before.contains(#/(?:yield|out)\s*(?:of|:)?\s*$/#) {
                d.yieldGrams = d.yieldGrams ?? value
            } else if after.contains(#/^\s*(?:of )?water/#) || before.contains(#/water\s*(?:of|:)?\s*$/#) {
                d.waterGrams = d.waterGrams ?? value
            } else {
                unlabeled.append(value)
            }
        }
        unlabeled.sort()
        if d.doseGrams == nil, let first = unlabeled.first, first <= 120 || unlabeled.count > 1 {
            d.doseGrams = first
            unlabeled.removeFirst()
        }
        guard let output = unlabeled.last else { return }
        if d.method == .espresso {
            if d.yieldGrams == nil { d.yieldGrams = output }
        } else if d.waterGrams == nil {
            d.waterGrams = output
        }
    }

    /// The words that aren't measurements, e.g. "great coffee!" or "sweet and juicy but a bit sour".
    static func comment(in text: String) -> String? {
        let parts = text.split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { part in
                let p = part.lowercased()
                guard !p.isEmpty, !p.contains(where: \.isNumber) else { return false }
                if p.contains("⭐") || p.contains("★") { return false }
                if BrewMethod(lenient: p) != nil, p.split(separator: " ").count <= 2 { return false }
                if p.wholeMatch(of: #/(?:at |off the )?boil(?:ing|ed)?(?: water)?/#) != nil { return false }
                return true
            }
        let joined = parts.joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
}
