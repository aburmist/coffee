import CoffeeKit
import Foundation
import SwiftData

/// Shared by the Log screen and the Siri intent: description → draft → saved brew.
@MainActor
enum BrewLogger {
    struct Result {
        var draft: BrewDraft
        /// Only what the description itself said, before any base was applied.
        var fromText: BrewDraft
        var bean: Bean?
        var usedAI: Bool
        /// What the draft was based on, e.g. "your last Espresso".
        var basedOn: String?
    }

    /// Understands a description. Recipe fields that aren't mentioned come from `base`
    /// when given (the timer, "same as last time").
    static func understand(_ text: String, base: BrewDraft?, context: ModelContext) async -> Result {
        let beans = DataStore.activeBeans(context)
        var parsed = BrewDraft()
        var usedAI = false
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let extracted = await BrewExtractor.extract(text, beanNames: beans.map(\.name))
            parsed = extracted.draft
            usedAI = extracted.usedAI
        }
        let draft = (base ?? BrewDraft()).overlaid(with: parsed)

        var bean: Bean?
        if let name = draft.beanName {
            bean = DataStore.bean(named: name, in: context)
        }
        if bean == nil, let id = BeanMatcher.match(text, in: beans.map { (id: $0.id, name: $0.name) }) {
            bean = beans.first { $0.id == id }
        }
        return Result(draft: draft, fromText: parsed, bean: bean, usedAI: usedAI, basedOn: nil)
    }

    /// For Siri: fills unmentioned recipe fields from the last brew of the same method,
    /// so a quick "espresso, a bit sour, 3 stars" still gets a full record and a dial-in tip.
    static func understandForQuickLog(_ text: String, context: ModelContext) async -> Result {
        var result = await understand(text, base: nil, context: context)
        let method = result.draft.method
        if let last = DataStore.lastBrew(context, method: method) {
            var base = BrewDraft(recipeOf: last.record)
            if result.bean != nil { base.beanName = nil }
            result.draft = base.overlaid(with: result.draft)
            if result.bean == nil { result.bean = last.bean }
            result.basedOn = "your last \(last.method.rawValue)"
        }
        if result.draft.method == nil { result.draft.method = AppSettings.defaultMethod }
        return result
    }

    /// Turns a draft into a stored brew.
    @discardableResult
    static func save(_ result: Result, originalText: String, context: ModelContext) -> Brew {
        let d = result.draft
        let record = BrewRecord(
            method: d.method ?? AppSettings.defaultMethod, grinder: AppSettings.grinder.name,
            grindSetting: d.grindSetting, doseGrams: d.doseGrams, waterGrams: d.waterGrams, yieldGrams: d.yieldGrams,
            temperatureC: d.temperatureC, timeSeconds: d.timeSeconds, rating: d.rating, extraction: d.extraction,
            acidity: d.acidity, sweetness: d.sweetness, body: d.body, bitterness: d.bitterness, aftertaste: d.aftertaste,
            flavors: d.flavors, comment: d.comment ?? "", originalText: originalText
        )
        var bean = result.bean
        if bean == nil, let name = d.beanName, !name.isEmpty {
            let newBean = Bean(record: BeanRecord(name: name))
            context.insert(newBean)
            bean = newBean
        }
        let brew = Brew(record: record, bean: bean)
        context.insert(brew)
        DataStore.saveAndSync(context)
        return brew
    }
}
