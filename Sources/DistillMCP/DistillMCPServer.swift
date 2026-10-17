import Foundation
import MCP

@main
struct DistillMCPServer {
    static func main() async throws {
        let server = Server(
            name: "distill",
            version: "0.2.0",
            capabilities: .init(tools: .init(listChanged: false))
        )

        let client = DistillClient()

        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            // Doku-Tools funktionieren offline — der App-Check gilt nur für den Rest
            if manualToolNames.contains(params.name) {
                return handleManualTool(params)
            }
            do {
                return try await handleTool(params, client: client)
            } catch let apiError as DistillAPIError {
                return CallTool.Result(content: [.text(apiError.message)], isError: true)
            } catch where isUnreachable(error) {
                return CallTool.Result(content: [.text(client.notReachableMessage)], isError: true)
            } catch {
                return CallTool.Result(content: [.text("Error: \(error.localizedDescription)")], isError: true)
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
