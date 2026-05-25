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
         description: "Fügt einen Ordner zur Überwachung hinzu",
         inputSchema: schema([
            "path": prop("string", "Absoluter Ordnerpfad"),
            "autoRename": prop("boolean", "Automatisch umbenennen")
         ], required: ["path"])),

    Tool(name: "app_status",
         description: "Gibt den aktuellen App-Status und Einstellungen zurück",
         inputSchema: schema([:])),

    Tool(name: "set_provider",
         description: "Wechselt den KI-Provider (Claude, OpenAI, Gemini, Ollama, Apple)",
         inputSchema: schema([
            "provider": prop("string", "Provider-Name: Claude, OpenAI, Gemini, Ollama oder Apple"),
            "model": prop("string", "Optionales Modell (z.B. llama3.1, gpt-4o)"),
            "endpoint": prop("string", "Optionaler Endpoint"),
            "apiKey": prop("string", "API Key für den Provider")
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
]

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
        let r = try await client.post("/v1/watch", body: ["path": folderPath, "autoRename": auto])
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
