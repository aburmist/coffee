import Foundation
import Testing
@testable import CoffeeKit

struct CSVTests {
    let utc = TimeZone(identifier: "UTC")!

    @Test func parsesQuotesAndNewlines() {
        let rows = CSV.parse("a,b,c\r\n1,\"x, y\",\"say \"\"hi\"\"\"\n2,\"multi\nline\",\n")
        #expect(rows == [["a", "b", "c"], ["1", "x, y", "say \"hi\""], ["2", "multi\nline", ""]])
    }

    @Test func escapeRoundTrip() {
        let text = CSV.write(header: ["a", "b"], rows: [["x, y", "q\"uote"]])
        #expect(CSV.parse(text) == [["a", "b"], ["x, y", "q\"uote"]])
    }

    @Test func brewRoundTrip() {
        let bean = UUID()
        let original = BrewRecord(
            date: Date(timeIntervalSince1970: 1_790_000_000), beanID: bean, beanName: "Guji",
            method: .espresso, grinder: "Baratza Encore", grindSetting: 5, doseGrams: 18, yieldGrams: 36,
            temperatureC: 93.3, timeSeconds: 28, rating: 4.5, extraction: .balanced, acidity: 3, sweetness: 4,
            flavors: ["chocolate", "cherry"], comment: "Nice, sweet", originalText: "espresso \"good\""
        )
        let result = BrewCSV.import(BrewCSV.export([original]))
        #expect(result.warnings.isEmpty)
        #expect(result.records == [original])
    }

    @Test func importsOldGoogleSheetDirectly() {
        let old = """
        coffee_weight,coffee_grind,water_weight,water_temperature,brew_time,brew_method,rating,comment,date
        18,4,60,Boil,50,Pour Over,⭐️⭐️⭐️⭐️,great coffee!,2024-09-15 08:30:00
        20,10,30,175 Green,60,Espresso,⭐️⭐️⭐️,test,2024-09-16 07:00:00
        ,,,,,,,,
        15,12,200,200 FrenchPress,90,Aeropress,⭐️⭐️⭐️⭐️⭐️,,9/17/2024 9:05:00
        """
        let r = BrewCSV.import(old, timeZone: utc)
        #expect(r.warnings.isEmpty)
        #expect(r.records.count == 3)
        let first = r.records[0]
        #expect(first.method == .pourOver)
        #expect(first.doseGrams == 18)
        #expect(first.waterGrams == 60)
        #expect(first.temperatureC == 100)
        #expect(first.timeSeconds == 50)
        #expect(first.rating == 4)
        #expect(first.comment == "great coffee!")
        #expect(first.date == DateCodec.read("2024-09-15T08:30:00Z"))
        let espresso = r.records[1]
        #expect(espresso.yieldGrams == 30)
        #expect(espresso.waterGrams == nil)
        #expect(espresso.temperatureC == 79)
        #expect(r.records[2].method == .aeroPress)
        #expect(r.records[2].temperatureC == 93)
        #expect(r.records[2].rating == 5)
        #expect(r.records[2].date == DateCodec.read("2024-09-17T09:05:00Z"))
    }

    @Test func reimportWithoutIDsIsStable() {
        let csv = "method,dose_g\nEspresso,18\nEspresso,18.5\n"
        let a = BrewCSV.import(csv).records.map(\.id)
        let b = BrewCSV.import(csv).records.map(\.id)
        #expect(a == b)
        #expect(Set(a).count == 2)
    }

    @Test func templateFileImports() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("../../templates/coffee-brews.csv").standardized
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return } // templates live outside the package in some checkouts
        let r = BrewCSV.import(text)
        #expect(r.warnings.isEmpty)
        #expect(r.records.count == 2)
        #expect(r.records[1].yieldGrams == 36)
        #expect(r.records[0].flavors == ["blueberry", "floral"])
    }

    @Test func skipsRowsWithoutMethod() {
        let r = BrewCSV.import("method,dose_g\n,18\ntea,3\nMoka,15\n")
        #expect(r.records.count == 1)
        #expect(r.warnings.count == 2)
    }

    @Test func temperatureCells() {
        #expect(BrewCSV.temperatureC(from: "93.5") == 93.5)
        #expect(BrewCSV.temperatureC(from: "200") == TemperatureUnit.fahrenheit.toCelsius(200))
        #expect(BrewCSV.temperatureC(from: "200F") == TemperatureUnit.fahrenheit.toCelsius(200))
        #expect(BrewCSV.temperatureC(from: "190 Oolong") == 88)
        #expect(BrewCSV.temperatureC(from: "hot") == nil)
    }

    @Test func beansRoundTrip() {
        let roast = DateCodec.read("2026-09-20")!
        let bean = BeanRecord(name: "Guji, washed", roaster: "Onyx", origin: "Ethiopia", process: "Washed",
                              roastLevel: "Light", roastDate: roast, roasterNotes: "peach; jasmine", finished: true)
        let back = BeanCSV.import(BeanCSV.export([bean])).records
        #expect(back == [bean])
    }

    @Test func mergePlan() {
        let a = BrewRecord(method: .espresso, doseGrams: 18)
        var a2 = a
        a2.doseGrams = 19
        let b = BrewRecord(method: .moka)
        let plan = SyncMerge.plan(imported: [a2, b, b], existing: [a])
        #expect(plan.insert == [b])
        #expect(plan.update == [a2])
        #expect(SyncMerge.plan(imported: [a], existing: [a]).update.isEmpty)
    }
}
