import Foundation
import MCP

// MARK: - Schema Helpers

func schema(_ props: [String: Value], required: [String] = []) -> Value {
    var obj: [String: Value] = [
        "type": .string("object"),
        "properties": .object(props)
    ]
    if !required.isEmpty {
        obj["required"] = .array(required.map { .string($0) })
    }
    return .object(obj)
}

func prop(_ type: String, _ desc: String) -> Value {
    .object(["type": .string(type), "description": .string(desc)])
}

func arrayProp(_ itemType: String, _ desc: String) -> Value {
    .object([
        "type": .string("array"),
        "items": .object(["type": .string(itemType)]),
        "description": .string(desc)
    ])
}

// MARK: - Tool Definitions

let allTools: [Tool] = [
    Tool(name: "rename_files",
         description: "Benennt Dateien um: Analysiert den Inhalt mit KI und benennt die Dateien mit beschreibenden Namen um",
         inputSchema: schema([
            "paths": arrayProp("string", "Absolute Dateipfade"),
            "template": prop("string", "Optionales Namenstemplate")
         ], required: ["paths"])),

    Tool(name: "suggest_names",
         description: "Schlägt neue Dateinamen vor ohne umzubenennen",
         inputSchema: schema([
            "paths": arrayProp("string", "Absolute Dateipfade"),
            "template": prop("string", "Optionales Namenstemplate")
         ], required: ["paths"])),

    Tool(name: "revert_rename",
         description: "Macht eine Umbenennung rückgängig",
         inputSchema: schema([
            "path": prop("string", "Pfad der umbenannten Datei")
         ], required: ["path"])),

    Tool(name: "get_rename_history",
         description: "Zeigt die Umbenennungs-Historie",
         inputSchema: schema([
            "limit": prop("integer", "Maximale Anzahl Einträge")
         ])),

    Tool(name: "watch_folder",
         description: "Fügt einen Ordner zur Überwachung hinzu. Die Antwort nennt unter 'existing', wie viele vorhandene Dateien noch nicht umbenannt sind",
         inputSchema: schema([
            "path": prop("string", "Absoluter Ordnerpfad"),
            "autoRename": prop("boolean", "Automatisch umbenennen"),
            "processExisting": prop("boolean", "Auch die schon im Ordner liegenden, noch nicht umbenannten Dateien verarbeiten (Standard: nein)")
         ], required: ["path"])),

    Tool(name: "process_existing_files",
         description: "Verarbeitet die vorhandenen, noch nicht umbenannten Dateien eines überwachten Ordners — mit Auto-Rename über die Warteschlange, sonst als Vorschläge",
         inputSchema: schema([
            "path": prop("string", "Absoluter Pfad eines überwachten Ordners")
         ], required: ["path"])),

    Tool(name: "queue_status",
         description: "Fortschritt der automatischen Verarbeitung: erkannt, verarbeitet, offen, umbenannt, fehlgeschlagen, aktuelle Datei und Fehlschläge mit Grund",
         inputSchema: schema([:])),

    Tool(name: "app_status",
         description: "Gibt den aktuellen App-Status und Einstellungen zurück",
         inputSchema: schema([:])),

    Tool(name: "set_provider",
         description: "Wechselt den KI-Provider (DistillCloud, Claude, OpenAI, Gemini, Ollama)",
         inputSchema: schema([
            "provider": prop("string", "Provider-Name: DistillCloud, Claude, OpenAI, Gemini oder Ollama"),
            "model": prop("string", "Optionales Modell (z.B. llama3.1, gpt-4o)"),
            "endpoint": prop("string", "Optionaler Endpoint"),
            "apiKey": prop("string", "API Key für den Provider"),
            "customInstructions": prop("string", "Eigene KI-Anweisungen, max 1000 Zeichen, gelten für alle Provider")
         ], required: ["provider"])),

    Tool(name: "get_rules",
         description: "Zeigt die aktuellen Umbenennungsregeln (Format, Datum, Casing, Kategorien)",
         inputSchema: schema([:])),

    Tool(name: "set_rules",
         description: "Ändert die Umbenennungsregeln",
         inputSchema: schema([
            "format": prop("string", "Namensformat z.B. {datum}{sep}{kategorie}{sep}{beschreibung}"),
            "dateFormat": prop("string", "YYYY-MM-DD, DD.MM.YYYY, MM-DD-YYYY, YYYYMMDD, Kein Datum"),
            "casing": prop("string", "kleinbuchstaben, Title Case, GROSSBUCHSTABEN, Wie von KI"),
            "separator": prop("string", "- oder _ oder ."),
            "prefix": prop("string", "Prefix vor dem Namen"),
            "suffix": prop("string", "Suffix nach dem Namen"),
            "categories": arrayProp("string", "Liste der Kategorien")
         ])),

    Tool(name: "search_manual",
         description: "Durchsucht das Distill-Benutzerhandbuch (offline, funktioniert auch ohne laufende App). Liefert passende Kapitel mit Textausschnitt",
         inputSchema: schema([
            "query": prop("string", "Suchbegriff, z.B. 'Ordnerüberwachung' oder 'rechnungsnummer'"),
            "language": prop("string", "de oder en (Standard: Systemsprache)")
         ], required: ["query"])),

    Tool(name: "get_manual_section",
         description: "Liefert ein Kapitel des Distill-Benutzerhandbuchs als Markdown (offline, funktioniert auch ohne laufende App)",
         inputSchema: schema([
            "section": prop("string", "Kapitel-Slug, z.B. folder-watching, rules-templates, api-automation, faq"),
            "language": prop("string", "de oder en (Standard: Systemsprache)")
         ], required: ["section"])),
]

// Doku-Tools laufen offline aus dem gebündelten JSON — kein App-Kontakt nötig
let manualToolNames: Set<String> = ["search_manual", "get_manual_section"]

func handleManualTool(_ params: CallTool.Parameters) -> CallTool.Result {
    let args = params.arguments ?? [:]
    let store = ManualStore.shared

    guard store.isAvailable else {
        return .init(content: [.text("The offline manual (distill-manual.json) was not found. The bridge inside Distill.app finds it on its own; for a bridge built from source, set DISTILL_MANUAL_JSON to /Applications/Distill.app/Contents/Resources/distill-manual.json.")], isError: true)
    }

    switch params.name {
    case "search_manual":
        let query = args["query"]?.stringValue ?? ""
        guard !query.isEmpty else {
            return .init(content: [.text("Parameter 'query' fehlt.")], isError: true)
        }
        let hits = store.search(query: query, locale: args["language"]?.stringValue)
        if hits.isEmpty {
            let slugs = store.availableSlugs(locale: args["language"]?.stringValue).joined(separator: ", ")
            return .init(content: [.text(jsonStr(["results": [], "hint": "Keine Treffer. Verfügbare Kapitel: \(slugs)"]))])
        }
        return .init(content: [.text(jsonStr(["results": hits]))])

    case "get_manual_section":
        let slug = args["section"]?.stringValue ?? ""
        let language = args["language"]?.stringValue
        guard let text = store.section(slug: slug, locale: language) else {
            let slugs = store.availableSlugs(locale: language).joined(separator: ", ")
            return .init(content: [.text("Kapitel '\(slug)' nicht gefunden. Verfügbar: \(slugs)")], isError: true)
        }
        return .init(content: [.text(text)])

    default:
        return .init(content: [.text("Unbekanntes Tool: \(params.name)")], isError: true)
    }
}

// MARK: - Tool Dispatch

func handleTool(_ params: CallTool.Parameters, client: DistillClient) async throws -> CallTool.Result {
    let args = params.arguments ?? [:]

    switch params.name {
    case "rename_files":
        let paths = args["paths"]?.arrayValue ?? []
        var body: [String: Any] = ["paths": paths.compactMap(\.stringValue)]
        if let t = args["template"]?.stringValue { body["template"] = t }
        let r = try await client.post("/v1/rename", body: body)
        return .init(content: [.text(jsonStr(r))])

    case "suggest_names":
        let paths = args["paths"]?.arrayValue ?? []
        var body: [String: Any] = ["paths": paths.compactMap(\.stringValue)]
        if let t = args["template"]?.stringValue { body["template"] = t }
        let r = try await client.post("/v1/suggest", body: body)
        return .init(content: [.text(jsonStr(r))])

    case "revert_rename":
        let path = args["path"]?.stringValue ?? ""
        let r = try await client.post("/v1/revert", body: ["id": path])
        return .init(content: [.text(jsonStr(r))])

    case "get_rename_history":
        var path = "/v1/history"
        if let limit = args["limit"]?.intValue {
            path += "?limit=\(limit)"
        }
        let r = try await client.get(path)
        return .init(content: [.text(jsonStr(r))])

    case "watch_folder":
        let folderPath = args["path"]?.stringValue ?? ""
        let auto = args["autoRename"]?.boolValue ?? false
        let existing = args["processExisting"]?.boolValue ?? false
        let r = try await client.post("/v1/watch", body: [
            "path": folderPath, "autoRename": auto, "processExisting": existing
        ])
        return .init(content: [.text(jsonStr(r))])

    case "process_existing_files":
        let folderPath = args["path"]?.stringValue ?? ""
        let r = try await client.post("/v1/watch/scan", body: ["path": folderPath])
        return .init(content: [.text(jsonStr(r))])

    case "queue_status":
        let r = try await client.get("/v1/queue")
        return .init(content: [.text(jsonStr(r))])

    case "app_status":
        let health = try await client.get("/v1/health")
        let settings = try await client.get("/v1/settings")
        var merged = health
        for (k, v) in settings { merged[k] = v }
        return .init(content: [.text(jsonStr(merged))])

    case "set_provider":
        let provider = args["provider"]?.stringValue ?? ""
        var body: [String: Any] = ["provider": provider]
        if let m = args["model"]?.stringValue { body["model"] = m }
        if let e = args["endpoint"]?.stringValue { body["endpoint"] = e }
        if let k = args["apiKey"]?.stringValue { body["apiKey"] = k }
        if let i = args["customInstructions"]?.stringValue { body["customInstructions"] = i }
        let r = try await client.post("/v1/providers", body: body)
        return .init(content: [.text(jsonStr(r))])

    case "get_rules":
        let r = try await client.get("/v1/rules")
        return .init(content: [.text(jsonStr(r))])

    case "set_rules":
        var body: [String: Any] = [:]
        if let f = args["format"]?.stringValue { body["format"] = f }
        if let d = args["dateFormat"]?.stringValue { body["dateFormat"] = d }
        if let c = args["casing"]?.stringValue { body["casing"] = c }
        if let s = args["separator"]?.stringValue { body["separator"] = s }
        if let p = args["prefix"]?.stringValue { body["prefix"] = p }
        if let s = args["suffix"]?.stringValue { body["suffix"] = s }
        if let cats = args["categories"]?.arrayValue {
            body["categories"] = cats.compactMap(\.stringValue)
        }
        let r = try await client.post("/v1/rules", body: body)
        return .init(content: [.text(jsonStr(r))])

    default:
        return .init(content: [.text("Unbekanntes Tool: \(params.name)")], isError: true)
    }
}

// MARK: - Helpers

private func jsonStr(_ dict: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
          let s = String(data: data, encoding: .utf8)
    else { return "\(dict)" }
    return s
}

extension Value {
    var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    var intValue: Int? { if case .int(let i) = self { return i }; return nil }
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }
    var arrayValue: [Value]? { if case .array(let a) = self { return a }; return nil }
}
