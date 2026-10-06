import CoffeeKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(SettingsKey.temperatureUnit) private var unit: TemperatureUnit = .fahrenheit
    @AppStorage(SettingsKey.grinderID) private var grinderID = Grinder.baratzaEncore.id
    @AppStorage(SettingsKey.defaultMethod) private var defaultMethod: BrewMethod = .espresso
    @Query private var brews: [Brew]
    @State private var sync = FolderSync.shared
    @State private var importing: ImportKind?
    @State private var message: String?

    enum ImportKind { case folder, file }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your setup") {
                    Picker("Grinder", selection: $grinderID) {
                        ForEach(Grinder.presets) { Text($0.name).tag($0.id) }
                    }
                    Picker("Usual method", selection: $defaultMethod) {
                        ForEach(BrewMethod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Temperature", selection: $unit) {
                        Text("°F").tag(TemperatureUnit.fahrenheit)
                        Text("°C").tag(TemperatureUnit.celsius)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if let name = sync.folderName {
                        LabeledContent("Folder", value: name)
                        if let last = sync.lastSync {
                            LabeledContent("Last written") {
                                Text("\(last, style: .relative) ago")
                            }
                        }
                        Button("Sync now", systemImage: "arrow.triangle.2.circlepath") {
                            let summary = sync.importFromFolder(context: context)
                            sync.export(context: context)
                            message = summary.text
                        }
                        Button("Change folder…", systemImage: "folder") { importing = .folder }
                        Button("Stop syncing", role: .destructive) { sync.clearFolder() }
                    } else {
                        Button("Choose sync folder…", systemImage: "folder.badge.plus") { importing = .folder }
                    }
                    if let error = sync.lastError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("History sync")
                } footer: {
                    Text("Pick a folder in iCloud Drive (or Google Drive, Dropbox…). After every change the app writes coffee-brews.csv and coffee-beans.csv there, so your history is on your Mac and in any spreadsheet app. If the folder already has those files, they're imported first. \(brews.count) brews on this iPhone.")
                }

                Section {
                    Button("Import a CSV file…", systemImage: "square.and.arrow.down") { importing = .file }
                    ShareLink(item: FolderSync.localBrewsFile) {
                        Label("Share brews CSV", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("Import works with the app's own CSV files, the templates, and a CSV download of the old Coffee Taster Google Sheet.")
                }

                Section("Siri") {
                    Text("“Hey Siri, log a coffee in Coffee Taster”").font(.callout)
                    Text("“Hey Siri, start an espresso timer in Coffee Taster”").font(.callout)
                    Text("You can also add these to the Action button or Shortcuts.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Apple Intelligence") {
                    Text(BrewExtractor.availabilityText).font(.callout)
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: Binding(get: { importing != nil }, set: { if !$0 { importing = nil } }),
                allowedContentTypes: importing == .folder ? [.folder] : [.commaSeparatedText, .plainText, .text]
            ) { result in
                let kind = importing
                importing = nil
                switch result {
                case .success(let url):
                    let summary = kind == .folder ? sync.setFolder(url, context: context) : sync.importFile(url, context: context)
                    message = summary.text
                case .failure(let error):
                    message = error.localizedDescription
                }
            }
            .alert("Sync", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }
}

/// First launch: explain the app in one screen and offer to pick the sync folder.
struct WelcomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var message: String?

    var body: some View {
        VStack(spacing: 24) {
            Image("Logo")
                .resizable().scaledToFit().frame(width: 120)
                .accessibilityHidden(true)
            Text("Coffee Taster").font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 14) {
                Label("Describe a brew in your own words — typed, spoken, or to Siri.", systemImage: "text.bubble")
                Label("Your iPhone fills in the details, on device.", systemImage: "sparkles")
                Label("Get a tip for the next cup: grind finer, hotter, longer.", systemImage: "dial.medium")
                Label("Your history is saved as CSV in a folder you choose.", systemImage: "folder")
            }
            .font(.body)
            Spacer()
            if let message {
                Text(message).font(.footnote).multilineTextAlignment(.center)
            }
            Button {
                picking = true
            } label: {
                Text("Choose sync folder").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button(message == nil ? "Later" : "Start brewing") { dismiss() }
        }
        .padding(28)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                message = FolderSync.shared.setFolder(url, context: context).text
            }
        }
        .interactiveDismissDisabled(false)
    }
}
