import CoffeeKit
import SwiftUI

/// Shown right after saving: what was logged and what to change next time.
struct BrewSavedView: View {
    let brew: Brew
    var onDone: () -> Void
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @AppStorage(SettingsKey.grinderID) private var grinderID = Grinder.baratzaEncore.id

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    BrewSummary(brew: brew, unit: unit)
                }
                .padding(.vertical, 4)
            }
            DialInSection(brew: brew, grinder: Grinder.preset(id: grinderID), unit: unit)
        }
        .navigationTitle("Logged")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDone).bold() }
        }
    }
}

struct DialInSection: View {
    let brew: Brew
    let grinder: Grinder
    let unit: TemperatureUnit

    var body: some View {
        let suggestions = DialIn.suggestions(for: brew.record, grinder: grinder, unit: unit)
        Section("Next time") {
            ForEach(suggestions, id: \.self) { s in
                VStack(alignment: .leading, spacing: 4) {
                    Label(s.title, systemImage: icon(s.kind)).font(.headline)
                    Text(s.reason).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func icon(_ kind: DialInSuggestion.Kind) -> String {
        switch kind {
        case .keep: "checkmark.seal"
        case .grindFiner: "arrow.down.right.and.arrow.up.left"
        case .grindCoarser: "arrow.up.left.and.arrow.down.right"
        case .hotter: "thermometer.high"
        case .cooler: "thermometer.low"
        case .longerRatio, .shorterRatio: "scalemass"
        case .moreDose: "plus.circle"
        case .addTaste: "questionmark.circle"
        }
    }
}

struct BrewSummary: View {
    let brew: Brew
    let unit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(brew.title).font(.headline)
            if !brew.recipeLine.isEmpty {
                Text(brew.recipeLine).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if let t = brew.temperatureC { Text(unit.format(celsius: t)) }
                if let r = brew.record.ratio { Text("1:\(Format.number((r * 10).rounded() / 10))") }
                if let rating = brew.rating { Text(Format.rating(rating)).foregroundStyle(.orange) }
                if let e = brew.extraction { Text(e.label) }
            }
            .font(.subheadline)
            if !brew.flavors.isEmpty {
                Text(brew.flavors.joined(separator: " · ")).font(.subheadline).foregroundStyle(.tint)
            }
            if !brew.comment.isEmpty {
                Text(brew.comment).font(.callout).italic()
            }
        }
    }
}
