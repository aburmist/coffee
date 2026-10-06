import CoffeeKit
import Foundation
import FoundationModels

/// What the on-device model fills in. Every field is optional so the model can
/// leave out anything the note doesn't mention.
@Generable
struct GeneratedBrew {
    @Guide(description: "Brew method if stated: Espresso, Pour Over, AeroPress, French Press, Clever, Moka, Drip or Cold Brew. V60, Chemex and Kalita count as Pour Over.")
    var method: String?

    @Guide(description: "Name of the coffee beans if stated. Use the exact known bean name when it matches.")
    var beanName: String?

    @Guide(description: "Grinder setting number, e.g. 'grind 22', 'size 4', '5 clicks' give 22, 4, 5.")
    var grindSetting: Double?

    @Guide(description: "Ground coffee dose in grams.")
    var doseGrams: Double?

    @Guide(description: "Water used in grams, for filter methods.")
    var waterGrams: Double?

    @Guide(description: "Espresso output (drink weight, yield) in grams.")
    var yieldGrams: Double?

    @Guide(description: "Water temperature number exactly as written.")
    var temperature: Double?

    @Guide(description: "Temperature unit if stated: F or C.")
    var temperatureUnit: String?

    @Guide(description: "Total brew time in seconds. 3:10 means 190; 28s means 28.")
    var brewSeconds: Int?

    @Guide(description: "Overall rating from 1 to 5 (half points allowed), only if the note gives a number or stars.")
    var rating: Double?

    @Guide(description: "sour (sour, sharp, tart, thin, under-extracted), bitter (bitter, harsh, dry, burnt, over-extracted) or balanced. Leave empty if taste balance isn't described.")
    var extraction: String?

    @Guide(description: "Acidity 1 to 5 if described (1 flat, 5 very bright).")
    var acidity: Int?

    @Guide(description: "Sweetness 1 to 5 if described.")
    var sweetness: Int?

    @Guide(description: "Body 1 to 5 if described (1 thin, 5 heavy/syrupy).")
    var body: Int?

    @Guide(description: "Flavor notes mentioned, as single lowercase words or short phrases from the flavor list.")
    var flavors: [String]

    @Guide(description: "The person's own words about the coffee, without the numbers. Empty if there are none.")
    var comment: String?
}

enum BrewExtractor {
    static var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// A short explanation for Settings and the Log screen.
    static var availabilityText: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "Using Apple Intelligence on this iPhone."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings for smarter filling. Using basic matching for now."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Using basic matching for now."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence. Using basic matching."
        case .unavailable:
            return "Apple Intelligence isn't available. Using basic matching."
        }
    }

    static let instructions = """
    You read short notes about a cup of coffee someone brewed and pull out the brewing details.
    Only fill a field when the note states it. Never guess or invent values.
    Numbers like "18g" are grams; "3:10" is minutes and seconds.
    """

    /// Turns a description into a draft. Uses the on-device model when available,
    /// and the rule-based parser for precise numbers and as a fallback.
    static func extract(_ text: String, beanNames: [String]) async -> (draft: BrewDraft, usedAI: Bool) {
        let rules = BrewTextParser.parse(text)
        guard isModelAvailable else { return (rules, false) }

        var prompt = "Note: \(text)\n\n"
        if !beanNames.isEmpty {
            prompt += "Known bean names: \(beanNames.joined(separator: "; "))\n"
        }
        prompt += "Flavor list: \(Flavors.all.joined(separator: ", "))"

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt, generating: GeneratedBrew.self)
            let ai = draft(from: response.content)
            // Rules win on numbers they matched exactly; the model fills everything else
            // and is better at describing taste in the person's own words.
            var merged = rules.filling(from: ai)
            merged.extraction = rules.extraction ?? ai.extraction
            merged.flavors = ai.flavors.isEmpty ? rules.flavors : ai.flavors
            merged.comment = ai.comment ?? rules.comment
            return (merged.sanitized(), true)
        } catch {
            return (rules, false)
        }
    }

    static func draft(from g: GeneratedBrew) -> BrewDraft {
        var d = BrewDraft()
        d.method = g.method.flatMap(BrewMethod.init(lenient:))
        d.beanName = g.beanName.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        d.grindSetting = g.grindSetting
        d.doseGrams = g.doseGrams
        d.waterGrams = g.waterGrams
        d.yieldGrams = g.yieldGrams
        if let t = g.temperature {
            let isF = g.temperatureUnit?.uppercased().hasPrefix("F") == true || t > 110
            d.temperatureC = isF ? TemperatureUnit.fahrenheit.toCelsius(t) : t
        }
        d.timeSeconds = g.brewSeconds
        d.rating = g.rating
        d.extraction = g.extraction.flatMap(Extraction.init(lenient:))
        d.acidity = g.acidity
        d.sweetness = g.sweetness
        d.body = g.body
        d.flavors = g.flavors
        d.comment = g.comment
        return d.sanitized()
    }
}
