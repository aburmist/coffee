import Foundation

/// How temperatures are shown. Values are always stored in °C.
public enum TemperatureUnit: String, CaseIterable, Codable, Sendable, Identifiable {
    case fahrenheit = "F"
    case celsius = "C"

    public var id: String { rawValue }
    public var symbol: String { self == .fahrenheit ? "°F" : "°C" }

    /// Converts a stored °C value into this unit.
    public func fromCelsius(_ celsius: Double) -> Double {
        switch self {
        case .celsius: celsius
        case .fahrenheit: celsius * 9 / 5 + 32
        }
    }

    /// Converts a value in this unit into °C for storage.
    public func toCelsius(_ value: Double) -> Double {
        switch self {
        case .celsius: value
        case .fahrenheit: (value - 32) * 5 / 9
        }
    }

    /// "200°F" or "93°C", rounded to whole degrees.
    public func format(celsius: Double) -> String {
        "\(Int(fromCelsius(celsius).rounded()))\(symbol)"
    }
}

public enum Format {
    /// "3:10" for 190 seconds.
    public static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// "18" for 18.0, "18.5" for 18.5, "0.33" for 1/3.
    public static func number(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    /// "4.5★" for 4.5.
    public static func rating(_ value: Double) -> String {
        number(value) + "★"
    }
}

public enum Parse {
    /// Parses brew times like "3:10", "190", "190s", "28 sec", "3 min", "3m10s", "2.5 min".
    public static func duration(_ text: String) -> Int? {
        let t = text.lowercased().trimmingCharacters(in: .whitespaces)
        if let m = t.wholeMatch(of: #/(\d{1,2}):(\d{2})/#) {
            return Int(m.1)! * 60 + Int(m.2)!
        }
        if let m = t.wholeMatch(of: #/(\d+)\s*m(?:in(?:utes?)?)?\s*(\d+)\s*s(?:ec(?:onds?)?)?/#) {
            return Int(m.1)! * 60 + Int(m.2)!
        }
        if let m = t.wholeMatch(of: #/(\d+(?:\.\d+)?)\s*m(?:in(?:utes?|s)?)?/#) {
            return Int((Double(m.1)! * 60).rounded())
        }
        if let m = t.wholeMatch(of: #/(\d+)\s*(?:s|sec|secs|seconds?)?/#) {
            return Int(m.1)
        }
        return nil
    }

    /// Counts star symbols (⭐️, ⭐, ★). "⭐️" is one Character made of two scalars,
    /// so this counts scalars rather than Characters.
    public static func starCount(_ text: String) -> Int {
        text.unicodeScalars.filter { $0 == "\u{2B50}" || $0 == "\u{2605}" }.count
    }

    /// Parses a decimal number that may use a comma ("18,5").
    public static func number(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}
