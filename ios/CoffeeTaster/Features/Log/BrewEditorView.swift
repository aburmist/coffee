import CoffeeKit
import SwiftData
import SwiftUI
import UIKit

/// Review a brew filled in from a description, or edit a saved one.
struct BrewEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @AppStorage(SettingsKey.grinderID) private var grinderID = Grinder.baratzaEncore.id
    @Query(filter: #Predicate<Bean> { !$0.finished }, sort: \Bean.name) private var beans: [Bean]

    @State var form: BrewForm
    var existing: Brew? = nil
    /// Called after a successful save.
    var onSaved: (() -> Void)? = nil
    @State private var showFlavorPicker = false
    @State private var showTasteScales = false
    @State private var saved: Brew?

    private var grinder: Grinder { Grinder.preset(id: grinderID) }

    var body: some View {
        NavigationStack {
            if let saved {
                BrewSavedView(brew: saved) { dismiss() }
            } else {
                editor
            }
        }
    }

    private var editor: some View {
        Form {
            if !form.originalText.isEmpty, form.isNew {
                Section {
                    Text(form.originalText).font(.callout).foregroundStyle(.secondary)
                } footer: {
                    if !form.filled.isEmpty {
                        Label("Filled in from your description — check anything marked.", systemImage: "sparkles")
                    }
                }
            }

            Section("Coffee") {
                Picker(selection: $form.method) {
                    ForEach(BrewMethod.allCases) { Label($0.rawValue, systemImage: $0.symbolName).tag($0) }
                } label: { label("Method", "method") }

                Picker(selection: $form.beanID) {
                    Text("None").tag(UUID?.none)
                    ForEach(beans) { Text($0.name).tag(Optional($0.id)) }
                } label: { label("Beans", "bean") }

                if form.beanID == nil {
                    TextField("New bean name (optional)", text: $form.newBeanName)
                }
            }

            Section {
                numberRow("Grind (\(grinder.name))", "grind", text: $form.grind, unit: "", keyboard: .decimalPad)
                numberRow("Coffee", "dose", text: $form.dose, unit: "g", keyboard: .decimalPad)
                numberRow(form.method.usesYield ? "Espresso out" : "Water", form.method.usesYield ? "yield" : "water", text: $form.output, unit: "g", keyboard: .decimalPad)
                numberRow("Temperature", "temperature", text: $form.temperature, unit: unit.symbol, keyboard: .decimalPad)
                numberRow("Time", "time", text: $form.time, unit: "m:ss", keyboard: .numbersAndPunctuation)
            } header: {
                Text("Recipe")
            } footer: {
                if let ratio = form.ratioText {
                    Text("Ratio \(ratio) · usual for \(form.method.rawValue): 1:\(Format.number(form.method.defaultRatio))")
                }
            }

            Section("Taste") {
                HStack {
                    label("Rating", "rating")
                    Spacer()
                    StarRating(rating: $form.rating)
                }
                VStack(alignment: .leading) {
                    label("Balance", "extraction")
                    Picker("Balance", selection: $form.extraction) {
                        Text("Sour").tag(Extraction?.some(.sour))
                        Text("Balanced").tag(Extraction?.some(.balanced))
                        Text("Bitter").tag(Extraction?.some(.bitter))
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    if form.extraction != nil {
                        Button("Clear") { form.extraction = nil }.font(.caption)
                    }
                }
                Button {
                    showFlavorPicker = true
                } label: {
                    HStack {
                        label("Flavors", "flavors")
                        Spacer()
                        Text(form.flavors.isEmpty ? "Add" : form.flavors.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .tint(.primary)
                DisclosureGroup("Taste profile", isExpanded: $showTasteScales) {
                    ScaleRow(title: "Acidity", value: $form.acidity)
                    ScaleRow(title: "Sweetness", value: $form.sweetness)
                    ScaleRow(title: "Body", value: $form.body)
                    ScaleRow(title: "Bitterness", value: $form.bitterness)
                    ScaleRow(title: "Aftertaste", value: $form.aftertaste)
                }
                TextField("Notes", text: $form.comment, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                DatePicker("Brewed", selection: $form.date)
            }
        }
        .navigationTitle(form.isNew ? "Review" : "Edit Brew")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).bold()
            }
        }
        .sheet(isPresented: $showFlavorPicker) {
            FlavorPicker(selection: $form.flavors)
        }
        .onAppear {
            showTasteScales = [form.acidity, form.sweetness, form.body, form.bitterness, form.aftertaste].contains { $0 != nil }
        }
    }

    private func label(_ title: String, _ field: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            if form.filled.contains(field) {
                Image(systemName: "sparkles").font(.caption2).foregroundStyle(.tint)
                    .accessibilityLabel("filled in from your description")
            }
        }
    }

    private func numberRow(_ title: String, _ field: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType) -> some View {
        HStack {
            label(title, field)
            Spacer()
            TextField("–", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
        }
    }

    private func save() {
        var bean = beans.first { $0.id == form.beanID } ?? existing?.bean.flatMap { b in b.id == form.beanID ? b : nil }
        let newName = form.newBeanName.trimmingCharacters(in: .whitespacesAndNewlines)
        if bean == nil, !newName.isEmpty {
            if let match = DataStore.bean(named: newName, in: context) {
                bean = match
            } else {
                let b = Bean(record: BeanRecord(name: newName))
                context.insert(b)
                bean = b
            }
        }
        var record = form.record(unit: unit, grinderName: grinder.name, existingGrinder: existing?.grinder)
        record.beanID = bean?.id
        if let existing {
            existing.apply(record, bean: bean)
            DataStore.saveAndSync(context)
            onSaved?()
            dismiss()
        } else {
            let brew = Brew(record: record, bean: bean)
            context.insert(brew)
            DataStore.saveAndSync(context)
            onSaved?()
            withAnimation { saved = brew }
        }
    }
}

/// Five stars; tap a star for a whole rating, tap it again for a half.
struct StarRating: View {
    @Binding var rating: Double?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: symbol(for: star))
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .onTapGesture { tap(star) }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue(rating.map { "\(Format.number($0)) stars" } ?? "none")
        .accessibilityAdjustableAction { direction in
            let current = rating ?? 0
            rating = direction == .increment ? min(current + 0.5, 5) : max(current - 0.5, 0.5)
        }
    }

    private func symbol(for star: Int) -> String {
        let r = rating ?? 0
        if r >= Double(star) { return "star.fill" }
        if r >= Double(star) - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }

    private func tap(_ star: Int) {
        let s = Double(star)
        rating = rating == s ? s - 0.5 : s
    }
}

/// 1–5 dots with an empty state.
struct ScaleRow: View {
    let title: String
    @Binding var value: Int?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            ForEach(1...5, id: \.self) { n in
                Image(systemName: (value ?? 0) >= n ? "circle.fill" : "circle")
                    .foregroundStyle(.tint)
                    .onTapGesture { value = value == n ? nil : n }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityValue(value.map { "\($0) of 5" } ?? "not set")
        .accessibilityAdjustableAction { direction in
            let v = value ?? 0
            value = direction == .increment ? min(v + 1, 5) : (v <= 1 ? nil : v - 1)
        }
    }
}

struct FlavorPicker: View {
    @Binding var selection: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Flavors.families) { family in
                    Section(family.name) {
                        FlowChips(items: family.notes, selection: $selection)
                    }
                }
            }
            .navigationTitle("Flavors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { selection = [] }.disabled(selection.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct FlowChips: View {
    let items: [String]
    @Binding var selection: [String]

    var body: some View {
        ChipLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let on = selection.contains(item)
                Button {
                    if on { selection.removeAll { $0 == item } } else { selection.append(item) }
                } label: {
                    Text(item)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary), in: Capsule())
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Lays out chips left to right, wrapping onto new lines.
struct ChipLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let addition = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            rows[rows.count - 1].indices.append(i)
            rows[rows.count - 1].width += addition
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
