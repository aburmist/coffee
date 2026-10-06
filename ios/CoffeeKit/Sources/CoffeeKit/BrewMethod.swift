import Foundation

public enum BrewMethod: String, CaseIterable, Codable, Sendable, Identifiable {
    case espresso = "Espresso"
    case pourOver = "Pour Over"
    case aeroPress = "AeroPress"
    case frenchPress = "French Press"
    case clever = "Clever"
    case moka = "Moka"
    case drip = "Drip"
    case coldBrew = "Cold Brew"
    case other = "Other"

    public var id: String { rawValue }

    /// Espresso is measured by drink weight (yield), everything else by water in.
    public var usesYield: Bool { self == .espresso }

    /// Default coffee : water (or coffee : yield) ratio, as the "x" in 1:x.
    public var defaultRatio: Double {
        switch self {
        case .espresso: 2
        case .aeroPress: 12.5
        case .pourOver: 16.7
        case .clever, .frenchPress: 15
        case .moka: 7
        case .drip: 16.7
        case .coldBrew: 8
        case .other: 16
        }
    }

    public var defaultDoseGrams: Double {
        switch self {
        case .espresso: 18
        case .aeroPress: 15
        case .moka: 15
        case .frenchPress: 30
        case .coldBrew: 100
        default: 18
        }
    }

    /// Default water temperature in °C, or nil where it doesn't apply.
    public var defaultTemperatureC: Double? {
        switch self {
        case .espresso: 93.5
        case .pourOver, .clever, .frenchPress: 94
        case .aeroPress: 85
        case .moka, .drip, .coldBrew, .other: nil
        }
    }

    /// Typical total brew time window in seconds, used for dial-in hints.
    public var targetTimeWindow: ClosedRange<Int>? {
        switch self {
        case .espresso: 25...32
        case .pourOver: 150...240
        case .aeroPress: 90...150
        case .clever: 150...240
        case .frenchPress: 220...300
        case .moka, .drip, .coldBrew, .other: nil
        }
    }

    /// How many grinder steps to move per suggestion. Espresso is far more sensitive.
    public var grindStepsPerAdjustment: Double {
        self == .espresso ? 1 : 2
    }

    /// SF Symbol for lists.
    public var symbolName: String {
        switch self {
        case .espresso: "cup.and.saucer.fill"
        case .pourOver, .clever, .drip: "drop.fill"
        case .aeroPress, .frenchPress: "cylinder.fill"
        case .moka: "flame.fill"
        case .coldBrew: "snowflake"
        case .other: "mug.fill"
        }
    }

    /// Words that identify the method in free text, longest first.
    static let aliases: [(String, BrewMethod)] = [
        ("french press", .frenchPress), ("frenchpress", .frenchPress), ("press pot", .frenchPress),
        ("pour over", .pourOver), ("pour-over", .pourOver), ("pourover", .pourOver),
        ("v60", .pourOver), ("chemex", .pourOver), ("kalita", .pourOver), ("origami", .pourOver),
        ("cold brew", .coldBrew), ("cold-brew", .coldBrew), ("coldbrew", .coldBrew),
        ("aeropress", .aeroPress), ("aero press", .aeroPress),
        ("espresso", .espresso), ("ristretto", .espresso), ("lungo", .espresso),
        ("clever", .clever), ("moka", .moka), ("drip", .drip), ("filter machine", .drip)
    ]

    /// Lenient match: "Aeropress", "pour-over", "V60" …
    public init?(lenient text: String) {
        let t = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if let exact = BrewMethod.allCases.first(where: { $0.rawValue.lowercased() == t }) {
            self = exact
            return
        }
        guard let match = BrewMethod.aliases.first(where: { t.contains($0.0) }) else { return nil }
        self = match.1
    }
}

/// How the cup tasted in terms of extraction, the main input for dial-in advice.
public enum Extraction: String, CaseIterable, Codable, Sendable, Identifiable {
    case sour
    case balanced
    case bitter

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }

    public init?(lenient text: String) {
        let t = text.lowercased()
        if let exact = Extraction(rawValue: t.trimmingCharacters(in: .whitespaces)) {
            self = exact
            return
        }
        if ["sour", "under-extracted", "underextracted", "tart", "salty"].contains(where: t.contains) {
            self = .sour
        } else if ["bitter", "over-extracted", "overextracted", "harsh", "astringent", "burnt", "ashy"].contains(where: t.contains) {
            self = .bitter
        } else if ["balanced", "perfect", "dialed", "spot on"].contains(where: t.contains) {
            self = .balanced
        } else {
            return nil
        }
    }
}
