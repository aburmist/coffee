import CoffeeKit
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Brew.date, order: .reverse) private var brews: [Brew]
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @State private var search = ""
    @State private var methodFilter: BrewMethod?

    private var filtered: [Brew] {
        brews.filter { brew in
            if let methodFilter, brew.method != methodFilter { return false }
            guard !search.isEmpty else { return true }
            let haystack = [brew.title, brew.comment, brew.flavors.joined(separator: " "), brew.originalText].joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { brew in
                    NavigationLink(value: brew.id) {
                        BrewRow(brew: brew)
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if brews.isEmpty {
                    ContentUnavailableView("No brews yet", systemImage: "cup.and.saucer",
                                           description: Text("Log your first brew on the Log tab."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Beans, notes, flavors")
            .toolbar {
                Menu {
                    Picker("Method", selection: $methodFilter) {
                        Text("All methods").tag(BrewMethod?.none)
                        ForEach(BrewMethod.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                } label: {
                    Label("Filter", systemImage: methodFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let brew = brews.first(where: { $0.id == id }) {
                    BrewDetailView(brew: brew)
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        DataStore.saveAndSync(context)
    }
}

struct BrewRow: View {
    let brew: Brew

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: brew.method.symbolName)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(brew.title).font(.headline).lineLimit(1)
                if !brew.recipeLine.isEmpty {
                    Text(brew.recipeLine).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(brew.date, format: .dateTime.weekday(.abbreviated).month().day().hour().minute())
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let r = brew.rating { Text(Format.rating(r)).foregroundStyle(.orange).font(.subheadline.bold()) }
                if let e = brew.extraction { Text(e.label).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

struct BrewDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @AppStorage(SettingsKey.grinderID) private var grinderID = Grinder.baratzaEncore.id
    let brew: Brew
    @State private var editing = false

    var body: some View {
        List {
            Section {
                BrewSummary(brew: brew, unit: unit)
                Text(brew.date, format: .dateTime.weekday(.wide).month().day().year().hour().minute())
                    .font(.footnote).foregroundStyle(.secondary)
            }
            DialInSection(brew: brew, grinder: Grinder.preset(id: grinderID), unit: unit)
            if [brew.acidity, brew.sweetness, brew.body, brew.bitterness, brew.aftertaste].contains(where: { $0 != nil }) {
                Section("Taste profile") {
                    TasteProfileChart(brew: brew)
                        .frame(height: 160)
                }
            }
            if !brew.originalText.isEmpty {
                Section("You said") { Text(brew.originalText).foregroundStyle(.secondary) }
            }
            Section {
                Button("Brew again", systemImage: "arrow.counterclockwise") {
                    var draft = BrewDraft(recipeOf: brew.record)
                    if let next = DialIn.suggestions(for: brew.record, grinder: Grinder.preset(id: grinderID), unit: unit)
                        .first(where: { $0.newGrindSetting != nil })?.newGrindSetting {
                        draft.grindSetting = next
                    }
                    router.log(from: LogBase(label: "this \(brew.method.rawValue) (with the suggested grind)", draft: draft))
                }
                Button("Start timer for this recipe", systemImage: "timer") {
                    router.startTimer(brew.method, dose: brew.doseGrams)
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    context.delete(brew)
                    DataStore.saveAndSync(context)
                    dismiss()
                }
            }
        }
        .navigationTitle(brew.method.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { editing = true }
        }
        .sheet(isPresented: $editing) {
            BrewEditorView(form: BrewForm(brew: brew, unit: unit), existing: brew)
        }
    }
}
