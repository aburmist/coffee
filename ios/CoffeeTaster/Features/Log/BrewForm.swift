import CoffeeKit
import Foundation
import Observation

/// Editable state for the review / edit screen. Numbers are kept as text while editing
/// so fields can be empty and accept "3:10" or "18,5".
@MainActor
@Observable
final class BrewForm {
    var id: UUID
    var date: Date
    var method: BrewMethod
    var beanID: UUID?
    /// A bean name the description mentioned that isn't in your list yet.
    var newBeanName: String
    var grind: String
    var dose: String
    var output: String
    var temperature: String
    var time: String
    var rating: Double?
    var extraction: Extraction?
    var acidity: Int?
    var sweetness: Int?
    var body: Int?
    var bitterness: Int?
    var aftertaste: Int?
    var flavors: [String]
    var comment: String
    var originalText: String
    /// Fields filled from the description, shown with a sparkle.
    var filled: Set<String>
    let isNew: Bool

    init(draft: BrewDraft, bean: Bean?, originalText: String, unit: TemperatureUnit, filled: Set<String>) {
        id = UUID()
        date = Date()
        let method = draft.method ?? AppSettings.defaultMethod
        self.method = method
        beanID = bean?.id
        newBeanName = bean == nil ? (draft.beanName ?? "") : ""
        grind = draft.grindSetting.map(Format.number) ?? ""
        dose = draft.doseGrams.map(Format.number) ?? ""
        let out = method.usesYield ? (draft.yieldGrams ?? draft.waterGrams) : (draft.waterGrams ?? draft.yieldGrams)
        output = out.map(Format.number) ?? ""
        temperature = draft.temperatureC.map { Format.number(unit.fromCelsius($0).rounded()) } ?? ""
        time = draft.timeSeconds.map(Format.duration) ?? ""
        rating = draft.rating
        extraction = draft.extraction
        acidity = draft.acidity
        sweetness = draft.sweetness
        body = draft.body
        bitterness = draft.bitterness
        aftertaste = draft.aftertaste
        flavors = draft.flavors
        comment = draft.comment ?? ""
        self.originalText = originalText
        self.filled = filled
        isNew = true
    }

    init(brew: Brew, unit: TemperatureUnit) {
        let r = brew.record
        id = r.id
        date = r.date
        method = r.method
        beanID = brew.bean?.id
        newBeanName = ""
        grind = r.grindSetting.map(Format.number) ?? ""
        dose = r.doseGrams.map(Format.number) ?? ""
        output = r.outputGrams.map(Format.number) ?? ""
        temperature = r.temperatureC.map { Format.number(unit.fromCelsius($0).rounded()) } ?? ""
        time = r.timeSeconds.map(Format.duration) ?? ""
        rating = r.rating
        extraction = r.extraction
        acidity = r.acidity
        sweetness = r.sweetness
        body = r.body
        bitterness = r.bitterness
        aftertaste = r.aftertaste
        flavors = r.flavors
        comment = r.comment
        originalText = r.originalText
        filled = []
        isNew = false
    }

    var doseValue: Double? { Parse.number(dose) }
    var outputValue: Double? { Parse.number(output) }

    /// "1:16.7 · target 1:16.7"
    var ratioText: String? {
        guard let d = doseValue, d > 0, let o = outputValue else { return nil }
        return "1:\(Format.number((o / d * 10).rounded() / 10))"
    }

    func record(unit: TemperatureUnit, grinderName: String, existingGrinder: String? = nil) -> BrewRecord {
        let out = outputValue
        return BrewRecord(
            id: id, date: date, beanID: beanID, method: method,
            grinder: existingGrinder ?? grinderName,
            grindSetting: Parse.number(grind), doseGrams: doseValue,
            waterGrams: method.usesYield ? nil : out, yieldGrams: method.usesYield ? out : nil,
            temperatureC: Parse.number(temperature).map { unit.toCelsius($0) },
            timeSeconds: Parse.duration(time), rating: rating, extraction: extraction,
            acidity: acidity, sweetness: sweetness, body: body, bitterness: bitterness, aftertaste: aftertaste,
            flavors: flavors, comment: comment.trimmingCharacters(in: .whitespacesAndNewlines), originalText: originalText
        )
    }
}
