import Foundation

// Gebündeltes Benutzerhandbuch für die Offline-Doku-Tools. Quelle ist der
// Suchindex der Website (store-frontend/lib/manualSearchData.ts), exportiert
// via scripts/export-distill-manual.ts in Resources/distill-manual.json.

struct ManualEntry: Codable, Sendable {
    let app: String?
    let locale: String
    let slug: String
    let title: String
    let subsection: String?
    let content: String
}

struct ManualStore: Sendable {
    let entries: [ManualEntry]
    let sectionTitles: [String: [String: String]]

    private struct ManualFile: Codable {
        let entries: [ManualEntry]
        let sectionTitles: [String: [String: String]]?
    }

    static let shared = ManualStore()

    init() {
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["DISTILL_MANUAL_JSON"] {
            candidates.append(URL(fileURLWithPath: env))
        }
        let binDir = Bundle.main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent()
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        // Im App-Bundle: MacOS/../Resources; im Dev-Build: neben dem Binary
        candidates.append(binDir.deletingLastPathComponent().appendingPathComponent("Resources/distill-manual.json"))
        candidates.append(binDir.appendingPathComponent("distill-manual.json"))

        for url in candidates {
            if let data = try? Data(contentsOf: url) {
                if let file = try? JSONDecoder().decode(ManualFile.self, from: data) {
                    entries = file.entries
                    sectionTitles = file.sectionTitles ?? [:]
                    return
                }
                if let plain = try? JSONDecoder().decode([ManualEntry].self, from: data) {
                    entries = plain
                    sectionTitles = [:]
                    return
                }
            }
        }
        entries = []
        sectionTitles = [:]
    }

    var isAvailable: Bool { !entries.isEmpty }

    private func normalizedLocale(_ raw: String?) -> String {
        let l = (raw ?? Locale.preferredLanguages.first ?? "de").lowercased()
        return l.hasPrefix("en") ? "en" : "de"
    }

    func availableSlugs(locale rawLocale: String?) -> [String] {
        let locale = normalizedLocale(rawLocale)
        var seen: Set<String> = []
        return entries.filter { $0.locale == locale }.compactMap {
            seen.insert($0.slug).inserted ? $0.slug : nil
        }
    }

    func search(query: String, locale rawLocale: String?, limit: Int = 5) -> [[String: Any]] {
        let locale = normalizedLocale(rawLocale)
        let needle = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        // Auch die Umlaut-Transkription probieren: "ordnerueberwachung" → "ordneruberwachung"
        let transcribed = needle
            .replacingOccurrences(of: "ae", with: "a")
            .replacingOccurrences(of: "oe", with: "o")
            .replacingOccurrences(of: "ue", with: "u")
            .replacingOccurrences(of: "ss", with: "ß")
        let needles = needle == transcribed ? [needle] : [needle, transcribed]

        var scored: [(score: Int, entry: ManualEntry, snippet: String)] = []
        for entry in entries where entry.locale == locale {
            let title = (entry.title + " " + (entry.subsection ?? ""))
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            let content = entry.content.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)

            var best: (score: Int, range: Range<String.Index>?)? = nil
            for n in needles {
                if let r = title.range(of: n) {
                    best = (3, content.range(of: n)); _ = r
                    break
                }
                if let r = content.range(of: n) {
                    if best == nil { best = (1, r) }
                }
            }
            guard let hit = best else { continue }

            var snippet = String(entry.content.prefix(200))
            if let r = hit.range {
                let start = content.index(r.lowerBound, offsetBy: -120, limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(r.upperBound, offsetBy: 120, limitedBy: content.endIndex) ?? content.endIndex
                let offsetStart = content.distance(from: content.startIndex, to: start)
                let offsetEnd = content.distance(from: content.startIndex, to: end)
                let cs = entry.content.index(entry.content.startIndex, offsetBy: min(offsetStart, entry.content.count))
                let ce = entry.content.index(entry.content.startIndex, offsetBy: min(offsetEnd, entry.content.count))
                snippet = "…" + entry.content[cs..<ce] + "…"
            }
            scored.append((hit.score, entry, snippet))
        }

        return scored.sorted { $0.score > $1.score }.prefix(limit).map { hit in
            var d: [String: Any] = [
                "section": hit.entry.slug,
                "title": hit.entry.title,
                "snippet": hit.snippet,
                "locale": hit.entry.locale
            ]
            if let sub = hit.entry.subsection { d["subsection"] = sub }
            return d
        }
    }

    func section(slug: String, locale rawLocale: String?) -> String? {
        let locale = normalizedLocale(rawLocale)
        let parts = entries.filter { $0.locale == locale && $0.slug == slug }
        guard !parts.isEmpty else { return nil }

        let heading = sectionTitles[slug]?[locale] ?? parts[0].title
        var out = "# \(heading)\n"
        for part in parts {
            if let sub = part.subsection, !sub.isEmpty {
                out += "\n## \(sub)\n\n\(part.content)\n"
            } else {
                out += "\n\(part.content)\n"
            }
        }
        return out
    }
}
