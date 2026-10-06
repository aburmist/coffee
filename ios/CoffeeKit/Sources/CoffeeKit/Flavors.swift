import Foundation

/// Flavor notes based on the SCA coffee taster's flavor wheel, grouped by family.
public enum Flavors {
    public struct Family: Sendable, Identifiable {
        public let name: String
        public let notes: [String]
        public var id: String { name }
    }

    public static let families: [Family] = [
        Family(name: "Fruity", notes: ["blueberry", "strawberry", "raspberry", "blackberry", "cherry", "grape", "apple", "pear", "peach", "apricot", "plum", "pineapple", "mango", "lemon", "lime", "orange", "grapefruit", "raisin", "fig", "prune"]),
        Family(name: "Floral", notes: ["jasmine", "rose", "chamomile", "black tea", "bergamot"]),
        Family(name: "Sweet", notes: ["honey", "caramel", "brown sugar", "maple", "molasses", "vanilla"]),
        Family(name: "Nutty / Cocoa", notes: ["chocolate", "dark chocolate", "milk chocolate", "cocoa", "almond", "hazelnut", "peanut"]),
        Family(name: "Spices", notes: ["cinnamon", "clove", "nutmeg", "anise", "pepper"]),
        Family(name: "Roasted", notes: ["toast", "malt", "tobacco", "smoky"]),
        Family(name: "Green / Vegetal", notes: ["herbal", "grassy", "green pepper", "peapod"]),
        Family(name: "Texture", notes: ["juicy", "silky", "creamy", "syrupy", "clean", "winey"]),
    ]

    public static let all: [String] = families.flatMap(\.notes)

    /// Common words people use, mapped onto the list above.
    static let synonyms: [String: String] = [
        "berries": "blueberry", "berry": "blueberry", "citrus": "lemon", "citrusy": "lemon",
        "chocolatey": "chocolate", "chocolaty": "chocolate", "nutty": "hazelnut", "nuts": "almond",
        "floral": "jasmine", "flowery": "jasmine", "caramelly": "caramel",
        "stone fruit": "peach", "tea-like": "black tea", "tea like": "black tea", "wine": "winey",
        "smoke": "smoky", "spicy": "pepper", "honeyed": "honey",
    ]

    /// Flavor notes mentioned in free text, in list order, without duplicates.
    public static func find(in text: String) -> [String] {
        let t = " " + text.lowercased().replacingOccurrences(of: #"[^a-z\- ]"#, with: " ", options: .regularExpression) + " "
        var found: [String] = []
        // Longer names first so "dark chocolate" wins over "chocolate".
        for note in all.sorted(by: { $0.count > $1.count }) where t.contains(" \(note) ") {
            if !found.contains(where: { $0.contains(note) }) { found.append(note) }
        }
        for (word, note) in synonyms where t.contains(" \(word) ") && !found.contains(note) {
            if !found.contains(where: { $0.contains(note) }) { found.append(note) }
        }
        return all.filter(found.contains)
    }

    /// Keeps only notes from the list (case-insensitive), mapping synonyms.
    public static func normalize(_ notes: [String]) -> [String] {
        var result: [String] = []
        for raw in notes {
            let n = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let mapped = all.contains(n) ? n : synonyms[n]
            if let mapped, !result.contains(mapped) { result.append(mapped) }
        }
        return result
    }
}
