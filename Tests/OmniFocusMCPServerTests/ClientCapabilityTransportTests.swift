import Foundation
import MCP
import Testing
@testable import OmniFocusMCPServer

@Suite("Client capability compatibility")
struct ClientCapabilityTransportTests {
    @Test("Object and boolean experimental capabilities no longer break initialization")
    func experimentalValues() throws {
        let data = Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","clientInfo":{"name":"codex","version":"1"},"capabilities":{"experimental":{"codex/auth-change":{},"boolean":true,"array":[],"number":1,"null":null,"string":"supported"},"roots":{"listChanged":true},"elicitation":{"form":{}}}}}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Request<Initialize>.self, from: data)
        }
        let request = try JSONDecoder().decode(Request<Initialize>.self, from: ClientCapabilityTransport.normalize(data))
        #expect(request.params.capabilities.experimental == ["string": "supported"])
        #expect(request.params.capabilities.roots?.listChanged == true)
        #expect(request.params.capabilities.elicitation?.form != nil)
        #expect(request.params.clientInfo.name == "codex")
        #expect(request.params.protocolVersion == "2025-11-25")
    }

    @Test("Compatible initialization and tool payloads pass through byte for byte")
    func unchangedMessages() {
        for message in [
            #"{"method":"initialize","params":{"capabilities":{"experimental":{"feature":"value"}}}}"#,
            #"{"method":"initialize","params":{"capabilities":{}}}"#,
            #"{"method":"tools/call","params":{"name":"create_task","arguments":{"experimental":{"feature":true}}}}"#,
            "not JSON"
        ] {
            let data = Data(message.utf8)
            #expect(ClientCapabilityTransport.normalize(data) == data)
        }
    }

    @Test("Batch initialization is normalized without changing other requests")
    func batch() throws {
        let data = Data(#"[{"method":"initialize","params":{"capabilities":{"experimental":{"feature":{}}}}},{"method":"tools/call","params":{"arguments":{"experimental":{"feature":true}}}}]"#.utf8)
        let result = try #require(JSONSerialization.jsonObject(with: ClientCapabilityTransport.normalize(data)) as? [[String: Any]])
        let params = try #require(result[0]["params"] as? [String: Any])
        let capabilities = try #require(params["capabilities"] as? [String: Any])
        #expect((capabilities["experimental"] as? [String: Any])?.isEmpty == true)
        let original = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(NSDictionary(dictionary: result[1]).isEqual(to: original[1]))
    }
}
