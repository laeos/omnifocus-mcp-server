import Foundation
import Logging
import MCP

/// Work around swift-sdk 0.12.1 decoding experimental client capabilities as
/// [String: String]. MCP clients may send arbitrary JSON values here. This server
/// does not use experimental client capabilities, so ignore unsupported values
/// while retaining the SDK's normal initialization and version negotiation.
actor ClientCapabilityTransport: Transport {
    private let base: any Transport
    nonisolated let logger = Logger(label: "omnifocus-mcp.transport")

    init(base: any Transport) {
        self.base = base
    }

    func connect() async throws { try await base.connect() }
    func disconnect() async { await base.disconnect() }
    func send(_ data: Data) async throws { try await base.send(data) }

    func receive() -> AsyncThrowingStream<Data, Swift.Error> {
        let base = self.base
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await data in await base.receive() {
                        try Task.checkCancellation()
                        continuation.yield(Self.normalize(data))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Leave tool arguments and invalid messages untouched; the SDK validates them.
    nonisolated static func normalize(_ data: Data) -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return data }
        var changed = false
        func normalizeRequest(_ object: Any) -> Any {
            guard var request = object as? [String: Any],
                  request["method"] as? String == "initialize",
                  var params = request["params"] as? [String: Any],
                  var capabilities = params["capabilities"] as? [String: Any],
                  let experimental = capabilities["experimental"] as? [String: Any]
            else { return object }
            let supported = experimental.filter { $0.value is String }
            guard supported.count != experimental.count else { return object }
            capabilities["experimental"] = supported
            params["capabilities"] = capabilities
            request["params"] = params
            changed = true
            return request
        }
        let normalized: Any
        if let batch = object as? [Any] {
            normalized = batch.map(normalizeRequest)
        } else {
            normalized = normalizeRequest(object)
        }
        guard changed else { return data }
        return (try? JSONSerialization.data(withJSONObject: normalized)) ?? data
    }
}
