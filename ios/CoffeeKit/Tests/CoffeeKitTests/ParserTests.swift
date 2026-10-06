import Foundation
import Testing
@testable import CoffeeKit

struct ParserTests {
    @Test func oldWebAppExample() {
        let d = BrewTextParser.parse("Pour over, boil, 18g, size 4, 50sec, 60g, 4 stars, great coffee!")
        #expect(d.method == .pourOver)
        #expect(d.temperatureC == 100)
        #expect(d.doseGrams == 18)
        #expect(d.waterGrams == 60)
        #expect(d.grindSetting == 4)
        #expect(d.timeSeconds == 50)
        #expect(d.rating == 4)
        #expect(d.comment == "great coffee!")
    }

    @Test func espressoInAndOut() {
        let d = BrewTextParser.parse("Espresso 18g in 36g out, 5 clicks, 28s at 200F, a bit sour, 3.5 stars")
        #expect(d.method == .espresso)
        #expect(d.doseGrams == 18)
        #expect(d.yieldGrams == 36)
        #expect(d.waterGrams == nil)
        #expect(d.grindSetting == 5)
        #expect(d.timeSeconds == 28)
        #expect(abs((d.temperatureC ?? 0) - 93.33) < 0.01)
        #expect(d.extraction == .sour)
        #expect(d.rating == 3.5)
        #expect(d.comment == "a bit sour")
    }

    @Test func espressoUnlabeledGrams() {
        let d = BrewTextParser.parse("espresso 18g 38g grind 6 30 sec bitter")
        #expect(d.doseGrams == 18)
        #expect(d.yieldGrams == 38)
        #expect(d.extraction == .bitter)
    }

    @Test func espressoRatioOnly() {
        let d = BrewTextParser.parse("espresso, 18g, ratio 1:2.5, 27 seconds")
        #expect(d.yieldGrams == 45)
        #expect(d.timeSeconds == 27)
    }

    @Test func v60Description() {
        let d = BrewTextParser.parse("V60, Ethiopia Guji, 18g, 300g at 94°, grind 22, 3:10, sweet and juicy but a bit sour, blueberry and jasmine, 4 stars")
        #expect(d.method == .pourOver)
        #expect(d.doseGrams == 18)
        #expect(d.waterGrams == 300)
        #expect(d.temperatureC == 94)
        #expect(d.grindSetting == 22)
        #expect(d.timeSeconds == 190)
        #expect(d.extraction == .sour)
        #expect(d.flavors == ["blueberry", "jasmine", "juicy"])
        #expect(d.rating == 4)
    }

    @Test func degreesWithoutUnitAbove110AreFahrenheit() {
        #expect(BrewTextParser.temperature(in: "205°") == TemperatureUnit.fahrenheit.toCelsius(205))
        #expect(BrewTextParser.temperature(in: "92 degrees") == 92)
        #expect(BrewTextParser.temperature(in: "92c") == 92)
    }

    @Test func timeFormats() {
        #expect(BrewTextParser.time(in: "took 3 min") == 180)
        #expect(BrewTextParser.time(in: "2.5 minutes") == 150)
        #expect(BrewTextParser.time(in: "4 min 30 sec") == 270)
        #expect(BrewTextParser.time(in: "ratio 1:16, 2:45") == 165)
        #expect(Parse.duration("3:10") == 190)
        #expect(Parse.duration("190s") == 190)
        #expect(Parse.duration("190") == 190)
        #expect(Parse.duration("3 min") == 180)
    }

    @Test func notBitterIsNotBitter() {
        #expect(BrewTextParser.extraction(in: "smooth, not bitter at all") == nil)
        #expect(BrewTextParser.extraction(in: "perfectly balanced") == .balanced)
        #expect(BrewTextParser.extraction(in: "sour and bitter") == nil)
    }

    @Test func starsAsEmoji() {
        #expect(BrewTextParser.rating(in: "⭐️⭐️⭐️⭐️") == 4)
        #expect(BrewTextParser.rating(in: "4/5") == 4)
        #expect(BrewTextParser.rating(in: "★★★") == 3)
        #expect(Parse.starCount("⭐️⭐️") == 2)
    }

    @Test func frenchPressWithWaterLabel() {
        let d = BrewTextParser.parse("French press 30 g coffee, 450 g water, 4 minutes, chocolate and nutty")
        #expect(d.method == .frenchPress)
        #expect(d.doseGrams == 30)
        #expect(d.waterGrams == 450)
        #expect(d.timeSeconds == 240)
        #expect(d.flavors == ["chocolate", "hazelnut"])
    }

    @Test func nothingRecognized() {
        let d = BrewTextParser.parse("lovely morning cup")
        #expect(d.method == nil)
        #expect(d.filledFields.isEmpty)
        #expect(d.comment == "lovely morning cup")
    }

    @Test func overlayKeepsUnmentionedFields() {
        var base = BrewDraft()
        base.method = .espresso
        base.doseGrams = 18
        base.grindSetting = 6
        var update = BrewDraft()
        update.grindSetting = 5
        update.extraction = .sour
        let merged = base.overlaid(with: update)
        #expect(merged.grindSetting == 5)
        #expect(merged.doseGrams == 18)
        #expect(merged.extraction == .sour)
        #expect(update.filling(from: base).doseGrams == 18)
        #expect(update.filling(from: base).grindSetting == 5)
    }
}
