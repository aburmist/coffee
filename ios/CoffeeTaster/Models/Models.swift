import CoffeeKit
import Foundation
import SwiftData

@Model
final class Bean {
    @Attribute(.unique) var id: UUID
    var name: String
    var roaster: String
    var origin: String
    var process: String
    var varietal: String
    var roastLevel: String
    var roastDate: Date?
    var roasterNotes: String
    var finished: Bool
    var createdAt: Date
    @Relationship(deleteRule: .nullify, inverse: \Brew.bean) var brews: [Brew] = []

    init(record: BeanRecord) {
        id = record.id
        name = record.name
        roaster = record.roaster
        origin = record.origin
        process = record.process
        varietal = record.varietal
        roastLevel = record.roastLevel
        roastDate = record.roastDate
        roasterNotes = record.roasterNotes
        finished = record.finished
        createdAt = Date()
    }

    var record: BeanRecord {
        BeanRecord(id: id, name: name, roaster: roaster, origin: origin, process: process, varietal: varietal,
                   roastLevel: roastLevel, roastDate: roastDate, roasterNotes: roasterNotes, finished: finished)
    }

    func apply(_ r: BeanRecord) {
        name = r.name
        roaster = r.roaster
        origin = r.origin
        process = r.process
        varietal = r.varietal
        roastLevel = r.roastLevel
        roastDate = r.roastDate
        roasterNotes = r.roasterNotes
        finished = r.finished
    }

    /// "Onyx · Ethiopia · 12 days off roast"
    var subtitle: String {
        var parts = [roaster, origin].filter { !$0.isEmpty }
        if let days = record.daysOffRoast() { parts.append("\(days) day\(days == 1 ? "" : "s") off roast") }
        return parts.joined(separator: " · ")
    }
}

@Model
final class Brew {
    @Attribute(.unique) var id: UUID
    var date: Date
    var bean: Bean?
    var methodRaw: String
    var grinder: String?
    var grindSetting: Double?
    var doseGrams: Double?
    var waterGrams: Double?
    var yieldGrams: Double?
    var temperatureC: Double?
    var timeSeconds: Int?
    var rating: Double?
    var extractionRaw: String?
    var acidity: Int?
    var sweetness: Int?
    var body: Int?
    var bitterness: Int?
    var aftertaste: Int?
    var flavors: [String]
    var comment: String
    var originalText: String

    init(record: BrewRecord, bean: Bean?) {
        id = record.id
        date = record.date
        methodRaw = record.method.rawValue
        flavors = []
        comment = ""
        originalText = ""
        apply(record, bean: bean)
    }

    var method: BrewMethod {
        get { BrewMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }

    var extraction: Extraction? {
        get { extractionRaw.flatMap(Extraction.init(rawValue:)) }
        set { extractionRaw = newValue?.rawValue }
    }

    var record: BrewRecord {
        BrewRecord(id: id, date: date, beanID: bean?.id, beanName: bean?.name, method: method, grinder: grinder,
                   grindSetting: grindSetting, doseGrams: doseGrams, waterGrams: waterGrams, yieldGrams: yieldGrams,
                   temperatureC: temperatureC, timeSeconds: timeSeconds, rating: rating, extraction: extraction,
                   acidity: acidity, sweetness: sweetness, body: body, bitterness: bitterness, aftertaste: aftertaste,
                   flavors: flavors, comment: comment, originalText: originalText)
    }

    func apply(_ r: BrewRecord, bean: Bean?) {
        date = r.date
        self.bean = bean
        method = r.method
        grinder = r.grinder
        grindSetting = r.grindSetting
        doseGrams = r.doseGrams
        waterGrams = r.waterGrams
        yieldGrams = r.yieldGrams
        temperatureC = r.temperatureC
        timeSeconds = r.timeSeconds
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
    }

    /// "Espresso · Ethiopia Guji"
    var title: String {
        [method.rawValue, bean?.name].compactMap { $0 }.joined(separator: " · ")
    }

    /// "18 g → 36 g · 0:28 · grind 5"
    var recipeLine: String {
        var parts: [String] = []
        let out = method.usesYield ? (yieldGrams ?? waterGrams) : (waterGrams ?? yieldGrams)
        switch (doseGrams, out) {
        case let (d?, o?): parts.append("\(Format.number(d)) g → \(Format.number(o)) g")
        case let (d?, nil): parts.append("\(Format.number(d)) g")
        case let (nil, o?): parts.append("→ \(Format.number(o)) g")
        default: break
        }
        if let t = timeSeconds { parts.append(Format.duration(t)) }
        if let g = grindSetting { parts.append("grind \(Format.number(g))") }
        return parts.joined(separator: " · ")
    }
}
