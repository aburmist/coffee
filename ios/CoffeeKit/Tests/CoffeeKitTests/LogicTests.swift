import Foundation
import Testing
@testable import CoffeeKit

struct UnitTests {
    @Test func fahrenheitRoundTrip() {
        let c = TemperatureUnit.fahrenheit.toCelsius(200)
        #expect(abs(c - 93.333) < 0.01)
        #expect(TemperatureUnit.fahrenheit.format(celsius: c) == "200°F")
        #expect(TemperatureUnit.celsius.format(celsius: 93.5) == "94°C")
    }

    @Test func formatting() {
        #expect(Format.duration(190) == "3:10")
        #expect(Format.duration(28) == "0:28")
        #expect(Format.number(18) == "18")
        #expect(Format.number(16.7) == "16.7")
        #expect(Format.rating(4.5) == "4.5★")
    }

    @Test func methodLenientNames() {
        #expect(BrewMethod(lenient: "Aeropress") == .aeroPress)
        #expect(BrewMethod(lenient: "pour-over") == .pourOver)
        #expect(BrewMethod(lenient: "Chemex") == .pourOver)
        #expect(BrewMethod(lenient: "FrenchPress") == .frenchPress)
        #expect(BrewMethod(lenient: "tea") == nil)
    }
}

struct GrinderTests {
    @Test func encoreMoves() {
        let g = Grinder.baratzaEncore
        #expect(g.move(5, steps: -1) == 4)
        #expect(g.move(1, steps: -1) == nil)
        #expect(g.move(40, steps: 2) == nil)
        #expect(g.clamp(0) == 1)
        #expect(g.describe(steps: -1) == "1 click")
        #expect(g.describe(steps: 2) == "2 clicks")
    }
}

struct DialInTests {
    let encore = Grinder.baratzaEncore

    func espresso(grind: Double = 6, time: Int? = 28, yield: Double = 36, extraction: Extraction? = nil, rating: Double? = nil) -> BrewRecord {
        BrewRecord(method: .espresso, grindSetting: grind, doseGrams: 18, yieldGrams: yield,
                   temperatureC: 93.33, timeSeconds: time, rating: rating, extraction: extraction)
    }

    @Test func sourEspressoGrindsOneClickFiner() {
        let s = DialIn.suggestions(for: espresso(extraction: .sour), grinder: encore)
        #expect(s.first?.kind == .grindFiner)
        #expect(s.first?.newGrindSetting == 5)
        #expect(s.first?.title == "Grind 1 click finer → 5")
        #expect(s.contains { $0.kind == .hotter && $0.title.contains("204°F") })
    }

    @Test func bitterEspressoGrindsCoarser() {
        let s = DialIn.suggestions(for: espresso(grind: 5, extraction: .bitter), grinder: encore)
        #expect(s.first?.newGrindSetting == 6)
        #expect(s.contains { $0.kind == .cooler })
    }

    @Test func shortSourShotSuggestsLongerRatio() {
        let s = DialIn.suggestions(for: espresso(yield: 27, extraction: .sour), grinder: encore)
        #expect(s.contains { $0.kind == .longerRatio && $0.title.contains("36 g") })
    }

    @Test func fastShotWithoutTasteIsTreatedAsUnderExtracted() {
        let s = DialIn.suggestions(for: espresso(time: 18), grinder: encore)
        #expect(s.first?.kind == .grindFiner)
        #expect(s.first?.reason.contains("fast") == true)
    }

    @Test func balancedMeansKeep() {
        let s = DialIn.suggestions(for: espresso(extraction: .balanced, rating: 4.5), grinder: encore)
        #expect(s.map(\.kind) == [.keep])
    }

    @Test func atFinestSettingFallsBackToTemperature() {
        let s = DialIn.suggestions(for: espresso(grind: 1, extraction: .sour), grinder: encore)
        #expect(!s.contains { $0.kind == .grindFiner })
        #expect(s.contains { $0.kind == .hotter })
    }

    @Test func filterMovesTwoSteps() {
        let brew = BrewRecord(method: .pourOver, grindSetting: 20, doseGrams: 18, waterGrams: 300, extraction: .sour)
        #expect(DialIn.suggestions(for: brew, grinder: encore).first?.newGrindSetting == 18)
    }

    @Test func unknownTasteAsksForIt() {
        let brew = BrewRecord(method: .pourOver, grindSetting: 20)
        #expect(DialIn.suggestions(for: brew, grinder: encore).map(\.kind) == [.addTaste])
    }

    @Test func bestBrew() {
        let a = BrewRecord(date: Date(timeIntervalSince1970: 1), method: .espresso, rating: 4)
        let b = BrewRecord(date: Date(timeIntervalSince1970: 2), method: .espresso, rating: 4)
        let c = BrewRecord(date: Date(timeIntervalSince1970: 3), method: .espresso, rating: 3)
        #expect(DialIn.best(of: [a, b, c])?.id == b.id)
    }
}

struct RecipeTests {
    @Test func espressoScalesToDose() {
        let r = RecipeLibrary.recipe(for: .espresso, doseGrams: 18)
        #expect(r.outputGrams == 36)
        #expect(r.stepIndex(at: 0) == 0)
        #expect(r.stepIndex(at: 10) == 1)
        #expect(r.stepIndex(at: 30) == 2)
    }

    @Test func pourOverSteps() {
        let r = RecipeLibrary.recipe(for: .pourOver, doseGrams: 18, ratio: 16.7)
        #expect(r.outputGrams == 301)
        #expect(r.steps[0].targetGrams == 45)
        #expect(r.secondsToNextStep(at: 40) == 5)
        #expect(r.secondsToNextStep(at: 200) == nil)
    }

    @Test func everyMethodHasSteps() {
        for m in BrewMethod.allCases {
            let r = RecipeLibrary.recipe(for: m)
            #expect(!r.steps.isEmpty)
            #expect(r.steps.map(\.startsAt) == r.steps.map(\.startsAt).sorted())
        }
    }
}

struct BeanTests {
    @Test func daysOffRoast() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let roast = DateCodec.read("2026-09-20", timeZone: cal.timeZone)!
        let now = DateCodec.read("2026-10-02 08:00:00", timeZone: cal.timeZone)!
        #expect(BeanRecord(name: "X", roastDate: roast).daysOffRoast(at: now, calendar: cal) == 12)
    }

    @Test func matcher() {
        let guji = UUID(), yirga = UUID(), house = UUID()
        let beans = [(id: guji, name: "Ethiopia Guji"), (id: yirga, name: "Ethiopia Yirgacheffe"), (id: house, name: "House Blend")]
        #expect(BeanMatcher.match("V60 with the ethiopia guji today", in: beans) == guji)
        #expect(BeanMatcher.match("house blend espresso", in: beans) == house)
        #expect(BeanMatcher.match("ethiopia something", in: beans) == nil)
    }
}
