import AppIntents
import CoffeeKit
import SwiftUI

/// "Hey Siri, log a coffee in Coffee Taster" → Siri asks how it was → saved, without opening the app.
struct LogCoffeeIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Coffee"
    static let description = IntentDescription("Describe a brew in one sentence. Coffee Taster fills in the details and saves it.")

    @Parameter(title: "Description",
               requestValueDialog: IntentDialog("How was your coffee? Say the method, any numbers, and how it tasted."))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let context = DataStore.container.mainContext
        let result = await BrewLogger.understandForQuickLog(text, context: context)
        let brew = BrewLogger.save(result, originalText: text, context: context)

        let tip = DialIn.suggestions(for: brew.record, grinder: AppSettings.grinder, unit: AppSettings.temperatureUnit).first
        var spoken = "Saved your \(brew.method.rawValue)"
        if let rating = brew.rating { spoken += ", \(Format.number(rating)) stars" }
        spoken += "."
        if let tip, tip.kind != .addTaste { spoken += " Next time: \(tip.title)." }

        return .result(dialog: IntentDialog(stringLiteral: spoken),
                       view: BrewSnippet(brew: brew.record, beanName: brew.bean?.name, basedOn: result.basedOn, tip: tip?.title))
    }
}

/// "Hey Siri, start an espresso timer in Coffee Taster"
struct StartBrewTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Brew Timer"
    static let description = IntentDescription("Opens Coffee Taster and starts the step-by-step brew timer.")
    static let openAppWhenRun = true

    @Parameter(title: "Method")
    var method: BrewMethodOption?

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.startTimer(method?.method ?? AppSettings.defaultMethod)
        return .result()
    }
}

enum BrewMethodOption: String, AppEnum {
    case espresso, pourOver, aeroPress, frenchPress, clever, moka, drip, coldBrew

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Brew Method"
    static let caseDisplayRepresentations: [BrewMethodOption: DisplayRepresentation] = [
        .espresso: "Espresso",
        .pourOver: DisplayRepresentation(title: "Pour Over", synonyms: ["V60", "pour-over", "Chemex"]),
        .aeroPress: "AeroPress",
        .frenchPress: "French Press",
        .clever: "Clever",
        .moka: DisplayRepresentation(title: "Moka", synonyms: ["moka pot"]),
        .drip: "Drip",
        .coldBrew: "Cold Brew",
    ]

    var method: BrewMethod {
        switch self {
        case .espresso: .espresso
        case .pourOver: .pourOver
        case .aeroPress: .aeroPress
        case .frenchPress: .frenchPress
        case .clever: .clever
        case .moka: .moka
        case .drip: .drip
        case .coldBrew: .coldBrew
        }
    }
}

struct CoffeeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogCoffeeIntent(),
            phrases: [
                "Log a coffee in \(.applicationName)",
                "Log my coffee in \(.applicationName)",
                "Log a brew in \(.applicationName)",
                "\(.applicationName) log coffee",
            ],
            shortTitle: "Log a Coffee",
            systemImageName: "cup.and.saucer"
        )
        AppShortcut(
            intent: StartBrewTimerIntent(),
            phrases: [
                "Start a \(\.$method) timer in \(.applicationName)",
                "Start an \(\.$method) timer in \(.applicationName)",
                "Start a brew timer in \(.applicationName)",
                "\(.applicationName) brew timer",
            ],
            shortTitle: "Brew Timer",
            systemImageName: "timer"
        )
    }
}

/// The card Siri shows after logging.
struct BrewSnippet: View {
    let brew: BrewRecord
    let beanName: String?
    let basedOn: String?
    let tip: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label([brew.method.rawValue, beanName].compactMap { $0 }.joined(separator: " · "), systemImage: brew.method.symbolName)
                .font(.headline)
            let numbers = [
                brew.doseGrams.map { "\(Format.number($0)) g" },
                brew.outputGrams.map { "→ \(Format.number($0)) g" },
                brew.timeSeconds.map(Format.duration),
                brew.grindSetting.map { "grind \(Format.number($0))" },
                brew.rating.map(Format.rating),
            ].compactMap { $0 }
            if !numbers.isEmpty {
                Text(numbers.joined(separator: " · ")).font(.subheadline)
            }
            if let basedOn {
                Text("Missing details copied from \(basedOn).").font(.caption).foregroundStyle(.secondary)
            }
            if let tip {
                Label(tip, systemImage: "dial.medium").font(.subheadline).foregroundStyle(.tint)
            }
        }
        .padding()
    }
}
