import CoffeeKit
import Foundation
import Observation
import SwiftData

/// UserDefaults keys and typed accessors for code outside views (intents, sync).
/// Views use `@AppStorage` with the same keys.
enum SettingsKey {
    static let temperatureUnit = "temperatureUnit"
    static let grinderID = "grinderID"
    static let defaultMethod = "defaultMethod"
    static let didOnboard = "didOnboard"
}

enum AppSettings {
    static var temperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: UserDefaults.standard.string(forKey: SettingsKey.temperatureUnit) ?? "") ?? .fahrenheit
    }

    static var grinder: Grinder {
        Grinder.preset(id: UserDefaults.standard.string(forKey: SettingsKey.grinderID) ?? Grinder.baratzaEncore.id)
    }

    static var defaultMethod: BrewMethod {
        BrewMethod(rawValue: UserDefaults.standard.string(forKey: SettingsKey.defaultMethod) ?? "") ?? .espresso
    }
}

enum AppTab: Hashable {
    case log, timer, history, beans, settings
}

/// Cross-screen navigation: the timer and Siri hand drafts to the Log tab.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var tab: AppTab = .log
    /// A starting point for the Log screen, e.g. from the timer or "Brew again".
    var pendingBase: LogBase?
    /// Set by the "Start brew timer" Siri intent or "Start timer for this recipe".
    var pendingTimerMethod: BrewMethod?
    var pendingTimerDose: Double?

    func log(from base: LogBase) {
        pendingBase = base
        tab = .log
    }

    func startTimer(_ method: BrewMethod, dose: Double? = nil) {
        pendingTimerMethod = method
        pendingTimerDose = dose
        tab = .timer
    }
}

/// What the Log screen starts from before you describe the taste.
struct LogBase: Equatable {
    var label: String
    var draft: BrewDraft
}

@MainActor
enum DataStore {
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Brew.self, Bean.self)
        } catch {
            fatalError("Could not open the brew database: \(error)")
        }
    }()

    /// Saves, then rewrites the CSV files in the sync folder.
    static func saveAndSync(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            FolderSync.shared.lastError = "Couldn't save: \(error.localizedDescription)"
        }
        FolderSync.shared.export(context: context)
    }

    static func lastBrew(_ context: ModelContext, method: BrewMethod? = nil) -> Brew? {
        var descriptor = FetchDescriptor<Brew>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        if let raw = method?.rawValue {
            descriptor.predicate = #Predicate<Brew> { $0.methodRaw == raw }
        }
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func activeBeans(_ context: ModelContext) -> [Bean] {
        let descriptor = FetchDescriptor<Bean>(predicate: #Predicate { !$0.finished }, sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func bean(named name: String, in context: ModelContext) -> Bean? {
        let all = (try? context.fetch(FetchDescriptor<Bean>())) ?? []
        if let exact = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return exact }
        let id = BeanMatcher.match(name, in: all.map { (id: $0.id, name: $0.name) })
        return all.first { $0.id == id }
    }
}
