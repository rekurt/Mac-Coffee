import Darwin
import MCP

let server = await MCPServerAdapter.makeServer()
let transport = MCPCompatibilityTransport()

do {
  try await server.start(transport: transport)
  await server.waitUntilCompleted()
  await server.stop()
} catch {
  MCPDiagnostics.report(String(describing: error))
  exit(EXIT_FAILURE)
}
