import Testing
import MCP
@testable import OmniFocusMCPServer

@Suite("ToolRouter")
struct ToolRouterTests {
    private func makeRouter(mode: CapabilityMode = .pro) async -> (ToolRouter, MockBridge) {
        let bridge = MockBridge()
        bridge.mockMode = mode
        let cache = TTLCache(enabled: true)
        let config = Configuration.load()
        let router = ToolRouter(bridge: bridge, cache: cache, config: config)
        await router.detectMode()
        return (router, bridge)
    }

    @Test("diagnostics returns server info")
    func diagnostics() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "diagnostics", arguments: nil)
        let text = extractText(result)
        #expect(text.contains("omnifocusRunning"))
        #expect(text.contains("\"mode\""))
        #expect(result.isError != true)
    }

    @Test("list_inbox calls bridge and returns result")
    func listInbox() async {
        let (router, bridge) = await makeRouter()
        bridge.jsResults["inInbox"] = """
        {"items": [{"id": "abc", "name": "Test"}], "totalCount": 1}
        """
        let result = await router.handle(name: "list_inbox", arguments: [
            "limit": .int(10),
        ])
        let text = extractText(result)
        #expect(text.contains("abc"))
        #expect(bridge.callCount == 1)
    }

    @Test("Pro-required tools fail in standard mode")
    func standardModeBlock() async {
        let (router, _) = await makeRouter(mode: .standard)
        let result = await router.handle(name: "list_inbox", arguments: nil)
        let text = extractText(result)
        #expect(text.contains("capability_unavailable"))
        #expect(result.isError == true)
    }

    @Test("standard mode tools work without Pro")
    func standardModePass() async {
        let (router, _) = await makeRouter(mode: .standard)
        let result = await router.handle(name: "open_task_url", arguments: [
            "id": .string("abc123"),
        ])
        // Should not error with capability_unavailable
        let text = extractText(result)
        #expect(!text.contains("capability_unavailable"))
    }

    @Test("get_task_by_id requires id parameter")
    func getTaskNoId() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "get_task_by_id", arguments: [:])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("create_task requires name parameter")
    func createTaskNoName() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_task", arguments: [:])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("update_task dry_run returns preview with token")
    func updateDryRun() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_task", arguments: [
            "id": .string("abc123"),
            "patch": .object(["status": .string("complete")]),
        ])
        let text = extractText(result)
        #expect(text.contains("dry_run"))
        #expect(text.contains("confirm_token"))
    }

    @Test("update_task without token fails for destructive ops")
    func updateNoToken() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_task", arguments: [
            "id": .string("abc123"),
            "patch": .object(["status": .string("complete")]),
            "dry_run": .bool(false),
        ])
        let text = extractText(result)
        #expect(text.contains("confirm_token"))
    }

    @Test("cached results avoid bridge call")
    func cacheHit() async {
        let (router, bridge) = await makeRouter()
        bridge.jsResults["inInbox"] = """
        {"items": [], "totalCount": 0}
        """
        // First call hits bridge
        _ = await router.handle(name: "list_inbox", arguments: ["limit": .int(10)])
        #expect(bridge.callCount == 1)

        // Second call should hit cache
        _ = await router.handle(name: "list_inbox", arguments: ["limit": .int(10)])
        #expect(bridge.callCount == 1)
    }

    @Test("mutation invalidates cache")
    func mutationInvalidatesCache() async {
        let (router, bridge) = await makeRouter()
        bridge.jsResults["inInbox"] = """
        {"items": [], "totalCount": 0}
        """
        bridge.jsResults["inbox"] = """
        {"id": "new1", "name": "Test", "url": "omnifocus:///task/new1"}
        """

        // Prime cache
        _ = await router.handle(name: "list_inbox", arguments: ["limit": .int(10)])
        #expect(bridge.callCount == 1)

        // Mutate
        _ = await router.handle(name: "create_task", arguments: [
            "name": .string("Test"),
        ])

        // Cache should be invalidated, so this hits bridge again
        _ = await router.handle(name: "list_inbox", arguments: ["limit": .int(10)])
        #expect(bridge.callCount == 3)
    }

    @Test("update_project dry_run returns preview with token")
    func updateProjectDryRun() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_project", arguments: [
            "id": .string("proj1"),
            "patch": .object(["status": .string("complete")]),
        ])
        let text = extractText(result)
        #expect(text.contains("dry_run"))
        #expect(text.contains("confirm_token"))
        #expect(text.contains("project_id"))
    }

    @Test("update_project without token fails for destructive ops")
    func updateProjectNoToken() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_project", arguments: [
            "id": .string("proj1"),
            "patch": .object(["status": .string("drop")]),
            "dry_run": .bool(false),
        ])
        let text = extractText(result)
        #expect(text.contains("confirm_token"))
    }

    @Test("update_project requires id parameter")
    func updateProjectNoId() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_project", arguments: [:])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("create_project requires name parameter")
    func createProjectNoName() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_project", arguments: [:])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("create_project returns new project")
    func createProjectHappyPath() async {
        let (router, bridge) = await makeRouter()
        bridge.jsResults["new Project"] = """
        {"id": "proj-new", "name": "Finance", "folderId": null, "folderName": null, "sequential": false, "singleton": false, "url": "omnifocus:///task/proj-new"}
        """
        let result = await router.handle(name: "create_project", arguments: [
            "name": .string("Finance"),
        ])
        let text = extractText(result)
        #expect(text.contains("proj-new"))
        #expect(result.isError != true)
    }

    @Test("create_project rejects bad reviewInterval")
    func createProjectBadReview() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_project", arguments: [
            "name": .string("P"),
            "reviewInterval": .object(["unit": .string("weeks")]),
        ])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("create_task rejects malformed RRULE")
    func createTaskBadRRule() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_task", arguments: [
            "name": .string("Recurring"),
            "repetitionRule": .object(["ruleString": .string("every month")]),
        ])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
        #expect(text.contains("FREQ="))
    }

    @Test("create_task accepts valid repetition rule with required date")
    func createTaskGoodRRule() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_task", arguments: [
            "name": .string("Pay rent"),
            "dueDate": .string("2026-03-26T09:00:00Z"),
            "repetitionRule": .object([
                "ruleString": .string("FREQ=MONTHLY;BYMONTHDAY=26"),
                "method": .string("due-after-completion"),
            ]),
        ])
        let text = extractText(result)
        #expect(!text.contains("invalid_input"))
    }

    @Test("create_task rejects due-after-completion repeat without a due date")
    func createTaskRepeatNoDueDate() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_task", arguments: [
            "name": .string("Pay rent"),
            "repetitionRule": .object([
                "ruleString": .string("FREQ=MONTHLY"),
                "method": .string("due-after-completion"),
            ]),
        ])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
        #expect(text.contains("due date"))
    }

    @Test("create_task rejects fixed repeat with no dates")
    func createTaskRepeatNoDates() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_task", arguments: [
            "name": .string("Water plants"),
            "repetitionRule": .object(["ruleString": .string("FREQ=WEEKLY")]),
        ])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("create_task accepts start-after-completion repeat with a defer date")
    func createTaskRepeatDeferOk() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "create_task", arguments: [
            "name": .string("Review budget"),
            "deferDate": .string("2026-03-01T09:00:00Z"),
            "repetitionRule": .object([
                "ruleString": .string("FREQ=WEEKLY"),
                "method": .string("start-after-completion"),
            ]),
        ])
        let text = extractText(result)
        #expect(!text.contains("invalid_input"))
    }

    @Test("update_task rejects malformed RRULE in patch")
    func updateTaskBadRRule() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_task", arguments: [
            "id": .string("abc"),
            "patch": .object(["repetitionRule": .object(["ruleString": .string("weekly")])]),
        ])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
    }

    @Test("update_task surfaces repetition_requires_date as invalid_input")
    func updateTaskRepeatDateErrorSurfaced() async {
        let (router, bridge) = await makeRouter()
        bridge.jsResults["repetition_requires_date"] = """
        {"error": "repetition_requires_date", "message": "A 'due-after-completion' repeat requires a due date."}
        """
        let result = await router.handle(name: "update_task", arguments: [
            "id": .string("abc"),
            "patch": .object(["repetitionRule": .object([
                "ruleString": .string("FREQ=MONTHLY"),
                "method": .string("due-after-completion"),
            ])]),
            "dry_run": .bool(false),
        ])
        let text = extractText(result)
        #expect(text.contains("invalid_input"))
        #expect(text.contains("due date"))
        #expect(result.isError == true)
    }

    @Test("update_task accepts clearing repetition rule")
    func updateTaskClearRRule() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "update_task", arguments: [
            "id": .string("abc"),
            "patch": .object(["repetitionRule": .null]),
        ])
        let text = extractText(result)
        // Clearing (null) is not a destructive status change and passes validation
        #expect(!text.contains("invalid_input"))
    }

    @Test("unknown tool returns error")
    func unknownTool() async {
        let (router, _) = await makeRouter()
        let result = await router.handle(name: "nonexistent_tool", arguments: nil)
        let text = extractText(result)
        #expect(text.contains("Unknown tool"))
        #expect(result.isError == true)
    }

    // MARK: - Helpers

    private func extractText(_ result: CallTool.Result) -> String {
        result.content.compactMap { content in
            if case .text(let text, _, _) = content {
                return text
            }
            return nil
        }.joined()
    }
}
