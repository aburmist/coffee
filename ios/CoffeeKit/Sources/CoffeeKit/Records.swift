import Foundation

/// A brew as plain values. The app's SwiftData model converts to and from this type;
/// CSV sync, dial-in and tests work on it directly.
public struct BrewRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var beanID: UUID?
    public var beanName: String?
    public var method: BrewMethod
    public var grinder: String?
    public var grindSetting: Double?
    public var doseGrams: Double?
    public var waterGrams: Double?
    public var yieldGrams: Double?
    public var temperatureC: Double?
    public var timeSeconds: Int?
    public var rating: Double?
    public var extraction: Extraction?
    public var acidity: Int?
    public var sweetness: Int?
    public var body: Int?
    public var bitterness: Int?
    public var aftertaste: Int?
    public var flavors: [String]
    public var comment: String
    public var originalText: String

    public init(
        id: UUID = UUID(), date: Date = Date(), beanID: UUID? = nil, beanName: String? = nil,
        method: BrewMethod, grinder: String? = nil, grindSetting: Double? = nil,
        doseGrams: Double? = nil, waterGrams: Double? = nil, yieldGrams: Double? = nil,
        temperatureC: Double? = nil, timeSeconds: Int? = nil, rating: Double? = nil,
        extraction: Extraction? = nil, acidity: Int? = nil, sweetness: Int? = nil, body: Int? = nil,
        bitterness: Int? = nil, aftertaste: Int? = nil, flavors: [String] = [],
        comment: String = "", originalText: String = ""
    ) {
        self.id = id
        self.date = date
        self.beanID = beanID
        self.beanName = beanName
        self.method = method
        self.grinder = grinder
        self.grindSetting = grindSetting
        self.doseGrams = doseGrams
        self.waterGrams = waterGrams
        self.yieldGrams = yieldGrams
        self.temperatureC = temperatureC
        self.timeSeconds = timeSeconds
        self.rating = rating
        self.extraction = extraction
        self.acidity = acidity
        self.sweetness = sweetness
        self.body = body
        self.bitterness = bitterness
        self.aftertaste = aftertaste
        self.flavors = flavors
        self.comment = comment
        self.originalText = originalText
    }

    /// Water for filter methods, drink weight for espresso.
    public var outputGrams: Double? { method.usesYield ? (yieldGrams ?? waterGrams) : (waterGrams ?? yieldGrams) }

    /// The "x" in 1:x, if dose and output are known.
    public var ratio: Double? {
        guard let dose = doseGrams, dose > 0, let out = outputGrams else { return nil }
        return out / dose
    }
}

public struct BeanRecord: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var roaster: String
    public var origin: String
    public var process: String
    public var varietal: String
    public var roastLevel: String
    public var roastDate: Date?
    public var roasterNotes: String
    public var finished: Bool

    public init(
        id: UUID = UUID(), name: String, roaster: String = "", origin: String = "", process: String = "",
        varietal: String = "", roastLevel: String = "", roastDate: Date? = nil, roasterNotes: String = "",
        finished: Bool = false
    ) {
        self.id = id
        self.name = name
        self.roaster = roaster
        self.origin = origin
        self.process = process
        self.varietal = varietal
        self.roastLevel = roastLevel
        self.roastDate = roastDate
        self.roasterNotes = roasterNotes
        self.finished = finished
    }

    /// Whole days between roast date and `date`.
    public func daysOffRoast(at date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let roastDate else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: roastDate), to: calendar.startOfDay(for: date)).day
    }

    public static let processes = ["Washed", "Natural", "Honey", "Anaerobic", "Other"]
    public static let roastLevels = ["Light", "Medium", "Dark"]
}

/// What was understood from a description. Every field is optional:
/// anything not mentioned stays nil instead of being guessed.
public struct BrewDraft: Codable, Hashable, Sendable {
    public var method: BrewMethod?
    public var beanName: String?
    public var grindSetting: Double?
    public var doseGrams: Double?
    public var waterGrams: Double?
    public var yieldGrams: Double?
    public var temperatureC: Double?
    public var timeSeconds: Int?
    public var rating: Double?
    public var extraction: Extraction?
    public var acidity: Int?
    public var sweetness: Int?
    public var body: Int?
    public var bitterness: Int?
    public var aftertaste: Int?
    public var flavors: [String] = []
    public var comment: String?

    public init() {}

    /// Starts a draft from an earlier brew: the recipe, not the tasting.
    public init(recipeOf brew: BrewRecord) {
        method = brew.method
        beanName = brew.beanName
        grindSetting = brew.grindSetting
        doseGrams = brew.doseGrams
        waterGrams = brew.waterGrams
        yieldGrams = brew.yieldGrams
        temperatureC = brew.temperatureC
        timeSeconds = brew.timeSeconds
    }

    /// Fields set in `other` win; fields it doesn't mention keep this draft's values.
    public func overlaid(with other: BrewDraft) -> BrewDraft {
        var d = self
        d.method = other.method ?? method
        d.beanName = other.beanName ?? beanName
        d.grindSetting = other.grindSetting ?? grindSetting
        d.doseGrams = other.doseGrams ?? doseGrams
        d.waterGrams = other.waterGrams ?? waterGrams
        d.yieldGrams = other.yieldGrams ?? yieldGrams
        d.temperatureC = other.temperatureC ?? temperatureC
        d.timeSeconds = other.timeSeconds ?? timeSeconds
        d.rating = other.rating ?? rating
        d.extraction = other.extraction ?? extraction
        d.acidity = other.acidity ?? acidity
        d.sweetness = other.sweetness ?? sweetness
        d.body = other.body ?? body
        d.bitterness = other.bitterness ?? bitterness
        d.aftertaste = other.aftertaste ?? aftertaste
        d.flavors = other.flavors.isEmpty ? flavors : other.flavors
        d.comment = other.comment ?? comment
        return d
    }

    /// Only fills fields that are still nil (used to back up the AI with the rule-based parser).
    public func filling(from other: BrewDraft) -> BrewDraft {
        other.overlaid(with: self)
    }

    /// Names of the fields that are set, for "filled in for you" highlighting.
    public var filledFields: Set<String> {
        var s: Set<String> = []
        if method != nil { s.insert("method") }
        if beanName != nil { s.insert("bean") }
        if grindSetting != nil { s.insert("grind") }
        if doseGrams != nil { s.insert("dose") }
        if waterGrams != nil { s.insert("water") }
        if yieldGrams != nil { s.insert("yield") }
        if temperatureC != nil { s.insert("temperature") }
        if timeSeconds != nil { s.insert("time") }
        if rating != nil { s.insert("rating") }
        if extraction != nil { s.insert("extraction") }
        if !flavors.isEmpty { s.insert("flavors") }
        return s
    }

    /// Fixes up common slips: espresso water that is really yield, values outside sane ranges.
    public func sanitized() -> BrewDraft {
        var d = self
        if d.method == .espresso, d.yieldGrams == nil, let w = d.waterGrams, w < 100 {
            d.yieldGrams = w
            d.waterGrams = nil
        }
        if let r = d.rating { d.rating = min(max((r * 2).rounded() / 2, 0.5), 5) }
        if let t = d.temperatureC, !(40...105).contains(t) { d.temperatureC = nil }
        if let g = d.doseGrams, !(1...500).contains(g) { d.doseGrams = nil }
        if let t = d.timeSeconds, t <= 0 { d.timeSeconds = nil }
        d.flavors = Flavors.normalize(d.flavors)
        func scale(_ v: Int?) -> Int? { v.map { min(max($0, 1), 5) } }
        d.acidity = scale(d.acidity)
        d.sweetness = scale(d.sweetness)
        d.body = scale(d.body)
        d.bitterness = scale(d.bitterness)
        d.aftertaste = scale(d.aftertaste)
        if let c = d.comment?.trimmingCharacters(in: .whitespacesAndNewlines), c.isEmpty { d.comment = nil }
        return d
    }
}
