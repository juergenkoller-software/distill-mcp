import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A non-2xx answer from Distill's local API.
///
/// Before 0.2.0 the bridge ignored the HTTP status: a wrong token or the
/// missing consent to the legal texts came back as a normal tool result.
/// Now every refusal becomes an MCP error with a sentence the agent can act on.
struct DistillAPIError: Error {
    let status: Int
    /// The `error` field of Distill's JSON answer, e.g. `legal_not_accepted`.
    let code: String?
    /// The `message` field, or the raw body if it was not JSON.
    let detail: String?

    var message: String {
        switch (status, code) {
        case (401, _):
            return "Distill rejected the API token (HTTP 401). Distill → Settings → API has a token set; "
                + "set DISTILL_API_TOKEN to the same value."
        case (403, "legal_not_accepted"):
            return "Distill is waiting for the user to accept its Terms of Use and Privacy Policy "
                + "(HTTP 403, legal_not_accepted). Until then the API answers only status requests. "
                + "The user opens the Distill window, where the “Legal Notice” sheet asks for acceptance. "
                + "An agent cannot accept on the user's behalf."
        default:
            let reason = [code, detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ": ")
            return "Distill answered HTTP \(status)" + (reason.isEmpty ? "." : ": \(reason)")
        }
    }

    init(status: Int, body: Data) {
        self.status = status
        let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        self.code = json?["error"] as? String
        if let json {
            self.detail = json["message"] as? String
        } else {
            let text = String(data: body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.detail = text.isEmpty ? nil : String(text.prefix(300))
        }
    }
}

actor DistillClient {
    private let base: URL
    private let token: String?
    let port: String

    init() {
        let port = ProcessInfo.processInfo.environment["DISTILL_API_PORT"] ?? "43821"
        self.port = port
        self.base = URL(string: "http://localhost:\(port)")!
        self.token = ProcessInfo.processInfo.environment["DISTILL_API_TOKEN"]
    }

    /// Shown when nothing listens on the port.
    nonisolated var notReachableMessage: String {
        "Distill is not reachable at http://localhost:\(port). Open Distill and check Distill → Settings → API. "
            + "The API and the MCP server are part of the Distill version from the website; "
            + "the Mac App Store version has neither."
    }

    private func authedRequest(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    /// Sends the request and throws `DistillAPIError` for every answer outside 2xx.
    private func send(_ req: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DistillAPIError(status: http.statusCode, body: data)
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["raw": String(data: data, encoding: .utf8) ?? ""]
    }

    func get(_ path: String) async throws -> [String: Any] {
        try await send(authedRequest(base.appendingPathComponent(path)))
    }

    func post(_ path: String, body: [String: Any] = [:]) async throws -> [String: Any] {
        var req = authedRequest(base.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await send(req)
    }

    func delete(_ path: String) async throws -> [String: Any] {
        var req = authedRequest(base.appendingPathComponent(path))
        req.httpMethod = "DELETE"
        return try await send(req)
    }
}

/// True when the app is not there at all (nothing listens on the port).
func isUnreachable(_ error: Error) -> Bool {
    guard let urlError = error as? URLError else { return false }
    switch urlError.code {
    case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .timedOut, .notConnectedToInternet:
        return true
    default:
        return false
    }
}
