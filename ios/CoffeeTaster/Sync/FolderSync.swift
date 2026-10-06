import CoffeeKit
import Foundation
import Observation
import SwiftData

/// Keeps `coffee-brews.csv` and `coffee-beans.csv` up to date in a folder you choose
/// (e.g. iCloud Drive → Coffee) and in the app's own Documents folder.
///
/// Free Apple IDs can't use iCloud/CloudKit directly, but a folder picked in the Files
/// picker can be written to with a security-scoped bookmark; the Files provider
/// (iCloud Drive, Google Drive, Dropbox …) does the syncing.
@MainActor
@Observable
final class FolderSync {
    static let shared = FolderSync()

    private(set) var folderName: String?
    private(set) var lastSync: Date?
    var lastError: String?

    private let bookmarkKey = "syncFolderBookmark"

    init() {
        folderName = resolveFolder()?.lastPathComponent
    }

    struct ImportSummary {
        var newBrews = 0
        var updatedBrews = 0
        var newBeans = 0
        var updatedBeans = 0
        var warnings: [String] = []

        var text: String {
            var parts: [String] = []
            if newBrews > 0 { parts.append("\(newBrews) new brew\(newBrews == 1 ? "" : "s")") }
            if updatedBrews > 0 { parts.append("\(updatedBrews) updated") }
            if newBeans > 0 { parts.append("\(newBeans) new bean\(newBeans == 1 ? "" : "s")") }
            var s = parts.isEmpty ? "Everything was already up to date." : "Imported " + parts.joined(separator: ", ") + "."
            if !warnings.isEmpty {
                s += "\n\n" + warnings.prefix(5).joined(separator: "\n")
                if warnings.count > 5 { s += "\n…and \(warnings.count - 5) more." }
            }
            return s
        }
    }

    // MARK: - Folder

    /// Saves access to a folder the person picked. Imports what's already there, then writes.
    func setFolder(_ url: URL, context: ModelContext) -> ImportSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            folderName = url.lastPathComponent
            lastError = nil
        } catch {
            lastError = "Couldn't keep access to that folder: \(error.localizedDescription)"
            return ImportSummary()
        }
        let summary = importFromFolder(context: context)
        export(context: context)
        return summary
    }

    func clearFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        folderName = nil
        lastSync = nil
    }

    private func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: bookmarkKey)
            }
        }
        return url
    }

    static var documentsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// The local copy, for sharing.
    static var localBrewsFile: URL { documentsFolder.appendingPathComponent(BrewCSV.fileName) }

    // MARK: - Export

    func export(context: ModelContext) {
        let brews = ((try? context.fetch(FetchDescriptor<Brew>())) ?? []).map(\.record)
        let beans = ((try? context.fetch(FetchDescriptor<Bean>())) ?? []).map(\.record)
        let files = [
            (BrewCSV.fileName, Data(BrewCSV.export(brews).utf8)),
            (BeanCSV.fileName, Data(BeanCSV.export(beans).utf8)),
        ]

        for (name, data) in files {
            try? data.write(to: Self.documentsFolder.appendingPathComponent(name), options: .atomic)
        }

        guard let folder = resolveFolder() else { return }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        do {
            for (name, data) in files {
                try Self.coordinatedWrite(data, to: folder.appendingPathComponent(name))
            }
            lastSync = Date()
            lastError = nil
        } catch {
            lastError = "Couldn't write to \(folder.lastPathComponent): \(error.localizedDescription). Your brews are safe on the iPhone; they'll be written on the next save."
        }
    }

    private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    private static func coordinatedRead(_ url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) || isCloudPlaceholder(url) else { return nil }
        try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        var text: String?
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { target in
            text = try? String(contentsOf: target, encoding: .utf8)
        }
        return text
    }

    private static func isCloudPlaceholder(_ url: URL) -> Bool {
        let placeholder = url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
        return FileManager.default.fileExists(atPath: placeholder.path)
    }

    // MARK: - Import

    /// Merges the CSV files in the sync folder into the database (by `id`).
    func importFromFolder(context: ModelContext) -> ImportSummary {
        guard let folder = resolveFolder() else { return ImportSummary() }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        let beans = Self.coordinatedRead(folder.appendingPathComponent(BeanCSV.fileName))
        let brews = Self.coordinatedRead(folder.appendingPathComponent(BrewCSV.fileName))
        return merge(brewsCSV: brews, beansCSV: beans, context: context)
    }

    /// Imports one CSV file picked by hand: a brews file (new format or the old
    /// Google Sheet download) or a beans file.
    func importFile(_ url: URL, context: ModelContext) -> ImportSummary {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let text = Self.coordinatedRead(url) ?? (try? String(contentsOf: url, encoding: .utf8)) else {
            return ImportSummary(warnings: ["Couldn't read \(url.lastPathComponent)."])
        }
        let header = (CSV.parse(text).first ?? []).map { $0.lowercased() }
        let isBeans = header.contains("name") && !header.contains("method") && !header.contains("brew_method")
        let summary = isBeans ? merge(brewsCSV: nil, beansCSV: text, context: context) : merge(brewsCSV: text, beansCSV: nil, context: context)
        export(context: context)
        return summary
    }

    func merge(brewsCSV: String?, beansCSV: String?, context: ModelContext) -> ImportSummary {
        var summary = ImportSummary()
        var allBeans = (try? context.fetch(FetchDescriptor<Bean>())) ?? []

        if let beansCSV {
            let result = BeanCSV.import(beansCSV)
            summary.warnings += result.warnings
            let plan = SyncMerge.plan(imported: result.records, existing: allBeans.map(\.record))
            for r in plan.insert {
                let bean = Bean(record: r)
                context.insert(bean)
                allBeans.append(bean)
            }
            for r in plan.update {
                allBeans.first { $0.id == r.id }?.apply(r)
            }
            summary.newBeans = plan.insert.count
            summary.updatedBeans = plan.update.count
        }

        if let brewsCSV {
            let result = BrewCSV.import(brewsCSV)
            summary.warnings += result.warnings
            let existing = (try? context.fetch(FetchDescriptor<Brew>())) ?? []
            let plan = SyncMerge.plan(imported: result.records, existing: existing.map(\.record))

            func bean(for r: BrewRecord) -> Bean? {
                if let id = r.beanID, let b = allBeans.first(where: { $0.id == id }) { return b }
                guard let name = r.beanName, !name.isEmpty else { return nil }
                if let b = allBeans.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return b }
                let b = Bean(record: BeanRecord(id: StableID.make(from: "bean:" + name.lowercased()), name: name))
                context.insert(b)
                allBeans.append(b)
                summary.newBeans += 1
                return b
            }
            for r in plan.insert { context.insert(Brew(record: r, bean: bean(for: r))) }
            for r in plan.update { existing.first { $0.id == r.id }?.apply(r, bean: bean(for: r)) }
            summary.newBrews = plan.insert.count
            summary.updatedBrews = plan.update.count
        }

        do {
            try context.save()
        } catch {
            summary.warnings.append("Couldn't save the import: \(error.localizedDescription)")
        }
        return summary
    }
}
