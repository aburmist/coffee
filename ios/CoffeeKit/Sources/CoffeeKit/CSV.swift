import Foundation

/// Minimal RFC 4180 CSV reading and writing.
public enum CSV {
    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = text.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar? = nil

        func endField() { row.append(field); field = "" }
        func endRow() {
            endField()
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while let c = pending ?? chars.next() {
            pending = nil
            if inQuotes {
                if c == "\"" {
                    if let next = chars.next() {
                        if next == "\"" { field.unicodeScalars.append("\"") } else { inQuotes = false; pending = next }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": endField()
                case "\r":
                    if let next = chars.next(), next != "\n" { pending = next }
                    endRow()
                case "\n": endRow()
                case "\u{FEFF}": break // byte-order mark
                default: field.unicodeScalars.append(c)
                }
            }
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    public static func escape(_ field: String) -> String {
        if field.contains(where: { ",\"\n\r".contains($0) }) || field.hasPrefix(" ") || field.hasSuffix(" ") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    public static func write(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }
}

/// A stable UUID derived from text, so re-importing rows that have no `id` doesn't duplicate them.
public enum StableID {
    public static func make(from text: String) -> UUID {
        func fnv(_ seed: UInt64) -> UInt64 {
            var h: UInt64 = 0xcbf29ce484222325 ^ seed
            for b in text.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
            return h
        }
        let a = fnv(0), b = fnv(0x9e3779b97f4a7c15)
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: a >> (8 * UInt64(i)))
            bytes[8 + i] = UInt8(truncatingIfNeeded: b >> (8 * UInt64(i)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5 style
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

public struct CSVImportResult<Record: Sendable>: Sendable {
    public var records: [Record]
    /// Human-readable notes about skipped rows ("Row 7: no brew method").
    public var warnings: [String]
}

// MARK: - Brews

public enum BrewCSV {
    public static let fileName = "coffee-brews.csv"

    public static let header = [
        "id", "date", "bean_id", "bean_name", "method", "grinder", "grind_setting", "dose_g", "water_g",
        "yield_g", "temp_c", "time_s", "rating", "extraction", "acidity", "sweetness", "body", "bitterness",
        "aftertaste", "flavors", "comment", "original_text",
    ]

    /// Column names from the old Coffee Taster Google Sheet, mapped onto the new ones.
    static let aliases: [String: String] = [
        "coffee_weight": "dose_g", "coffee_grind": "grind_setting", "water_weight": "water_g",
        "water_temperature": "temp_c", "temp_f": "temp_f", "brew_time": "time_s", "brew_method": "method",
        "notes": "comment",
    ]

    public static func export(_ brews: [BrewRecord]) -> String {
        let rows = brews.sorted { $0.date < $1.date }.map { b -> [String] in
            [
                b.id.uuidString, DateCodec.write(b.date), b.beanID?.uuidString ?? "", b.beanName ?? "",
                b.method.rawValue, b.grinder ?? "", n(b.grindSetting), n(b.doseGrams), n(b.waterGrams),
                n(b.yieldGrams), n(b.temperatureC.map { ($0 * 10).rounded() / 10 }), b.timeSeconds.map(String.init) ?? "",
                n(b.rating), b.extraction?.rawValue ?? "", i(b.acidity), i(b.sweetness), i(b.body),
                i(b.bitterness), i(b.aftertaste), b.flavors.joined(separator: ";"), b.comment, b.originalText,
            ]
        }
        return CSV.write(header: header, rows: rows)
    }

    public static func `import`(_ text: String, timeZone: TimeZone = .current) -> CSVImportResult<BrewRecord> {
        let rows = CSV.parse(text)
        guard let head = rows.first else { return CSVImportResult(records: [], warnings: ["The file is empty."]) }
        let columns = head.map { name -> String in
            let key = name.trimmingCharacters(in: .whitespaces).lowercased()
            return aliases[key] ?? key
        }
        var records: [BrewRecord] = []
        var warnings: [String] = []

        for (offset, row) in rows.dropFirst().enumerated() {
            let line = offset + 2
            var cells: [String: String] = [:]
            for (i, column) in columns.enumerated() where i < row.count {
                cells[column] = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            func s(_ key: String) -> String? { cells[key].flatMap { $0.isEmpty ? nil : $0 } }
            func d(_ key: String) -> Double? { s(key).flatMap(Parse.number) }
            func int(_ key: String) -> Int? { d(key).map { Int($0.rounded()) } }

            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            guard let method = s("method").flatMap(BrewMethod.init(lenient:)) else {
                warnings.append("Row \(line): missing or unknown brew method \"\(cells["method"] ?? "")\" — skipped.")
                continue
            }
            let id = s("id").flatMap(UUID.init(uuidString:)) ?? StableID.make(from: row.joined(separator: "\u{1F}"))
            var temperature = s("temp_c").flatMap(temperatureC(from:))
            if temperature == nil, let f = d("temp_f") { temperature = TemperatureUnit.fahrenheit.toCelsius(f) }

            var brew = BrewRecord(
                id: id,
                date: s("date").flatMap { DateCodec.read($0, timeZone: timeZone) } ?? Date(),
                beanID: s("bean_id").flatMap(UUID.init(uuidString:)),
                beanName: s("bean_name"),
                method: method,
                grinder: s("grinder"),
                grindSetting: d("grind_setting"),
                doseGrams: d("dose_g"),
                waterGrams: d("water_g"),
                yieldGrams: d("yield_g"),
                temperatureC: temperature,
                timeSeconds: s("time_s").flatMap(Parse.duration),
                rating: s("rating").flatMap(rating(from:)),
                extraction: s("extraction").flatMap(Extraction.init(lenient:)),
                acidity: int("acidity"), sweetness: int("sweetness"), body: int("body"),
                bitterness: int("bitterness"), aftertaste: int("aftertaste"),
                flavors: (s("flavors") ?? "").split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty },
                comment: s("comment") ?? "",
                originalText: s("original_text") ?? ""
            )
            // The old web app stored espresso output in "water_weight".
            if method == .espresso, brew.yieldGrams == nil, let w = brew.waterGrams, w < 100 {
                brew.yieldGrams = w
                brew.waterGrams = nil
            }
            if s("date").flatMap({ DateCodec.read($0, timeZone: timeZone) }) == nil {
                warnings.append("Row \(line): no readable date — imported with today's date.")
            }
            records.append(brew)
        }
        return CSVImportResult(records: records, warnings: warnings)
    }

    /// "93.5", "200" (clearly °F), "200F", "93 °C", or the old app's presets like "200 FrenchPress".
    static func temperatureC(from text: String) -> Double? {
        let t = text.lowercased().replacingOccurrences(of: " ", with: "")
        let presets: [String: Double] = ["175green": 79, "185white": 85, "190oolong": 88, "200frenchpress": 93, "boil": 100]
        if let p = presets[t] { return p }
        guard let m = t.wholeMatch(of: #/(\d+(?:[.,]\d+)?)°?([cf])?/#), let v = Parse.number(String(m.1)) else { return nil }
        if m.2 == "f" || (m.2 == nil && v > 110) { return TemperatureUnit.fahrenheit.toCelsius(v) }
        return v
    }

    /// "4", "4.5", or "⭐️⭐️⭐️⭐️".
    static func rating(from text: String) -> Double? {
        if let v = Parse.number(text) { return v }
        let stars = Parse.starCount(text)
        return stars > 0 ? Double(stars) : nil
    }

    static func n(_ v: Double?) -> String { v.map(Format.number) ?? "" }
    static func i(_ v: Int?) -> String { v.map(String.init) ?? "" }
}

// MARK: - Beans

public enum BeanCSV {
    public static let fileName = "coffee-beans.csv"

    public static let header = ["id", "name", "roaster", "origin", "process", "varietal", "roast_level", "roast_date", "roaster_notes", "finished"]

    public static func export(_ beans: [BeanRecord]) -> String {
        let rows = beans.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { b in
            [b.id.uuidString, b.name, b.roaster, b.origin, b.process, b.varietal, b.roastLevel,
             b.roastDate.map(DateCodec.writeDay) ?? "", b.roasterNotes, b.finished ? "true" : "false"]
        }
        return CSV.write(header: header, rows: rows)
    }

    public static func `import`(_ text: String, timeZone: TimeZone = .current) -> CSVImportResult<BeanRecord> {
        let rows = CSV.parse(text)
        guard let head = rows.first else { return CSVImportResult(records: [], warnings: []) }
        let columns = head.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var records: [BeanRecord] = []
        var warnings: [String] = []
        for (offset, row) in rows.dropFirst().enumerated() {
            var cells: [String: String] = [:]
            for (i, column) in columns.enumerated() where i < row.count {
                cells[column] = row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            func s(_ key: String) -> String { cells[key] ?? "" }
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            guard !s("name").isEmpty else {
                warnings.append("Beans row \(offset + 2): no name — skipped.")
                continue
            }
            records.append(BeanRecord(
                id: UUID(uuidString: s("id")) ?? StableID.make(from: "bean:" + s("name").lowercased()),
                name: s("name"), roaster: s("roaster"), origin: s("origin"), process: s("process"),
                varietal: s("varietal"), roastLevel: s("roast_level"),
                roastDate: DateCodec.read(s("roast_date"), timeZone: timeZone),
                roasterNotes: s("roaster_notes"),
                finished: ["true", "yes", "1", "y"].contains(s("finished").lowercased())
            ))
        }
        return CSVImportResult(records: records, warnings: warnings)
    }
}

// MARK: - Dates

public enum DateCodec {
    public static func write(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f.string(from: date)
    }

    public static func writeDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// ISO 8601, the old sheet's "2024-09-15 08:30:00", or Google Sheets' US format "9/15/2024 8:30:00".
    public static func read(_ text: String, timeZone: TimeZone = .current) -> Date? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: t) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: t) { return d }

        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd",
                       "M/d/yyyy H:mm:ss", "M/d/yyyy H:mm", "M/d/yyyy"] {
            f.dateFormat = format
            if let d = f.date(from: t) { return d }
        }
        return nil
    }
}

// MARK: - Merging

public enum SyncMerge {
    /// Splits imported records into ones to insert and ones to update, by `id`.
    /// Existing records are only updated when the imported copy differs.
    public static func plan<R: Identifiable & Equatable>(imported: [R], existing: [R]) -> (insert: [R], update: [R]) where R.ID == UUID {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var insert: [R] = []
        var update: [R] = []
        var seen: Set<UUID> = []
        for r in imported where seen.insert(r.id).inserted {
            if let current = byID[r.id] {
                if current != r { update.append(r) }
            } else {
                insert.append(r)
            }
        }
        return (insert, update)
    }
}

// MARK: - Bean matching

public enum BeanMatcher {
    /// Finds which of your beans a description or name refers to.
    /// A bean matches when all words of its name (ignoring very short ones) appear in the text.
    public static func match(_ text: String, in beans: [(id: UUID, name: String)]) -> UUID? {
        let t = words(text)
        var best: (UUID, Int)? = nil
        for bean in beans {
            let name = words(bean.name).filter { $0.count > 2 }
            guard !name.isEmpty, name.allSatisfy(t.contains) else { continue }
            if name.count > (best?.1 ?? 0) { best = (bean.id, name.count) }
        }
        return best?.0
    }

    static func words(_ s: String) -> Set<String> {
        Set(s.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
    }
}
