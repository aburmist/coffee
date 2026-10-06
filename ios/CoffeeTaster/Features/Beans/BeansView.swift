import Charts
import CoffeeKit
import SwiftData
import SwiftUI

struct BeansView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bean.name) private var beans: [Bean]
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                let active = beans.filter { !$0.finished }
                let finished = beans.filter(\.finished)
                if !active.isEmpty {
                    Section("On the shelf") {
                        ForEach(active) { bean in NavigationLink(value: bean.id) { BeanRow(bean: bean) } }
                    }
                }
                if !finished.isEmpty {
                    Section("Finished") {
                        ForEach(finished) { bean in NavigationLink(value: bean.id) { BeanRow(bean: bean) } }
                    }
                }
            }
            .overlay {
                if beans.isEmpty {
                    ContentUnavailableView {
                        Label("No beans yet", systemImage: "leaf")
                    } description: {
                        Text("Add a bag to track roast date and your best recipe for it. Beans you mention while logging are added for you.")
                    } actions: {
                        Button("Add beans") { adding = true }.buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Beans")
            .toolbar {
                Button("Add", systemImage: "plus") { adding = true }
            }
            .navigationDestination(for: UUID.self) { id in
                if let bean = beans.first(where: { $0.id == id }) { BeanDetailView(bean: bean) }
            }
            .sheet(isPresented: $adding) {
                BeanEditorView(record: BeanRecord(name: ""), existing: nil)
            }
        }
    }
}

struct BeanRow: View {
    let bean: Bean

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bean.name).font(.headline)
            if !bean.subtitle.isEmpty {
                Text(bean.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            if let best = DialIn.best(of: bean.brews.map(\.record)), let r = best.rating {
                Text("Best: \(Format.rating(r)) · \(best.method.rawValue)\(best.grindSetting.map { " · grind \(Format.number($0))" } ?? "")")
                    .font(.caption).foregroundStyle(.tint)
            }
        }
    }
}

struct BeanDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    let bean: Bean
    @State private var editing = false

    private var brews: [Brew] { bean.brews.sorted { $0.date > $1.date } }

    var body: some View {
        List {
            Section {
                if !bean.subtitle.isEmpty { Text(bean.subtitle) }
                let details = [bean.process, bean.varietal, bean.roastLevel].filter { !$0.isEmpty }
                if !details.isEmpty { Text(details.joined(separator: " · ")).foregroundStyle(.secondary) }
                if !bean.roasterNotes.isEmpty {
                    LabeledContent("Roaster's notes", value: bean.roasterNotes)
                }
            }

            if let best = DialIn.best(of: brews.map(\.record)), let brew = brews.first(where: { $0.id == best.id }) {
                Section("Best recipe so far") {
                    BrewSummary(brew: brew, unit: unit)
                    Button("Brew it again", systemImage: "arrow.counterclockwise") {
                        router.log(from: LogBase(label: "your best \(bean.name)", draft: BrewDraft(recipeOf: best)))
                    }
                }
            }

            let points = brews.compactMap { b -> (grind: Double, rating: Double, method: String)? in
                guard let g = b.grindSetting, let r = b.rating else { return nil }
                return (g, r, b.method.rawValue)
            }
            if points.count >= 2 {
                Section("Rating by grind") {
                    Chart(points.indices, id: \.self) { i in
                        PointMark(x: .value("Grind", points[i].grind), y: .value("Rating", points[i].rating))
                            .foregroundStyle(by: .value("Method", points[i].method))
                    }
                    .chartYScale(domain: 0...5)
                    .chartXAxisLabel("Grind setting")
                    .frame(height: 180)
                }
            }

            Section("Brews (\(brews.count))") {
                ForEach(brews) { brew in
                    NavigationLink {
                        BrewDetailView(brew: brew)
                    } label: {
                        BrewRow(brew: brew)
                    }
                }
            }
        }
        .navigationTitle(bean.name)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) {
            BeanEditorView(record: bean.record, existing: bean)
        }
    }
}

struct TasteProfileChart: View {
    let brew: Brew

    private struct Score: Identifiable {
        let name: String
        let value: Int
        var id: String { name }
    }

    private var scores: [Score] {
        [("Acidity", brew.acidity), ("Sweetness", brew.sweetness), ("Body", brew.body),
         ("Bitterness", brew.bitterness), ("Aftertaste", brew.aftertaste)]
            .compactMap { name, value in value.map { Score(name: name, value: $0) } }
    }

    var body: some View {
        Chart(scores) { item in
            BarMark(x: .value("Score", item.value), y: .value("Attribute", item.name))
                .foregroundStyle(.tint)
                .annotation(position: .trailing) { Text("\(item.value)").font(.caption) }
        }
        .chartXScale(domain: 0...5)
    }
}

struct BeanEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State var record: BeanRecord
    let existing: Bean?
    @State private var hasRoastDate = false
    @State private var scanning = false
    @State private var isReading = false
    @State private var scanNote: String?

    var body: some View {
        NavigationStack {
            Form {
                if existing == nil {
                    Section {
                        Button {
                            scanning = true
                        } label: {
                            HStack {
                                Label("Scan the bag", systemImage: "camera.viewfinder")
                                if isReading { Spacer(); ProgressView() }
                            }
                        }
                    } footer: {
                        Text(scanNote ?? "Take a photo of the label and the details are filled in for you.")
                    }
                }
                Section {
                    TextField("Name (e.g. Ethiopia Guji)", text: $record.name)
                    TextField("Roaster", text: $record.roaster)
                    TextField("Origin", text: $record.origin)
                }
                Section {
                    Picker("Process", selection: $record.process) {
                        Text("–").tag("")
                        ForEach(BeanRecord.processes, id: \.self) { Text($0).tag($0) }
                        if !record.process.isEmpty, !BeanRecord.processes.contains(record.process) {
                            Text(record.process).tag(record.process)
                        }
                    }
                    Picker("Roast", selection: $record.roastLevel) {
                        Text("–").tag("")
                        ForEach(BeanRecord.roastLevels, id: \.self) { Text($0).tag($0) }
                        if !record.roastLevel.isEmpty, !BeanRecord.roastLevels.contains(record.roastLevel) {
                            Text(record.roastLevel).tag(record.roastLevel)
                        }
                    }
                    TextField("Varietal", text: $record.varietal)
                    Toggle("Roast date known", isOn: $hasRoastDate)
                    if hasRoastDate {
                        DatePicker("Roasted on", selection: Binding(
                            get: { record.roastDate ?? Date() },
                            set: { record.roastDate = $0 }
                        ), in: ...Date(), displayedComponents: .date)
                    }
                }
                Section("Roaster's tasting notes") {
                    TextField("e.g. peach, jasmine, honey", text: $record.roasterNotes, axis: .vertical)
                }
                if existing != nil {
                    Section {
                        Toggle("Finished this bag", isOn: $record.finished)
                    }
                }
            }
            .navigationTitle(existing == nil ? "New Beans" : "Edit Beans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).bold()
                        .disabled(record.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { hasRoastDate = record.roastDate != nil }
            .onChange(of: hasRoastDate) { _, on in
                if !on { record.roastDate = nil } else if record.roastDate == nil { record.roastDate = Date() }
            }
            .fullScreenCover(isPresented: $scanning) {
                CameraPicker { image in
                    scanning = false
                    guard let image else { return }
                    Task { await read(image) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private func read(_ image: UIImage) async {
        isReading = true
        defer { isReading = false }
        guard let found = await BeanLabelReader.read(image) else {
            scanNote = "Couldn't read any text on that photo. Try again closer, in good light."
            return
        }
        func fill(_ current: inout String, _ new: String?) {
            if current.isEmpty, let new, !new.isEmpty { current = new }
        }
        fill(&record.name, found.name)
        fill(&record.roaster, found.roaster)
        fill(&record.origin, found.origin)
        fill(&record.process, found.process)
        fill(&record.varietal, found.varietal)
        fill(&record.roastLevel, found.roastLevel)
        fill(&record.roasterNotes, found.notes)
        if record.roastDate == nil, let date = found.roastDate {
            record.roastDate = date
            hasRoastDate = true
        }
        scanNote = "Filled in from the label — check the details."
    }

    private func save() {
        record.name = record.name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.apply(record)
        } else {
            context.insert(Bean(record: record))
        }
        DataStore.saveAndSync(context)
        dismiss()
    }
}
