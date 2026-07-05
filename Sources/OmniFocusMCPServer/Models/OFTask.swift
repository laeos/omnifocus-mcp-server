import Foundation

/// Canonical OmniFocus task representation.
/// Fields are optional to support field projection — only requested fields are populated.
struct OFTask: Codable, Hashable, Sendable {
    let id: String
    let name: String
    var note: String?
    var status: TaskStatus?
    var flagged: Bool?
    var completed: Bool?
    var dropped: Bool?
    var dueDate: String?
    var deferDate: String?
    var completionDate: String?
    var estimatedMinutes: Int?
    var projectId: String?
    var projectName: String?
    var parentId: String?
    var tagIds: [String]?
    var tagNames: [String]?
    var hasChildren: Bool?
    var sequential: Bool?
    var repetitionRule: OFRepetitionRule?
    var url: String?
}

enum TaskStatus: String, Codable, Hashable, Sendable {
    case active
    case completed
    case dropped
    case blocked
}

/// A task's recurrence, mirroring OmniFocus's `Task.RepetitionRule`.
/// `ruleString` is an ICS RRULE (e.g. "FREQ=MONTHLY;BYMONTHDAY=26").
struct OFRepetitionRule: Codable, Hashable, Sendable {
    let ruleString: String
    let method: RepetitionMethod
}

/// How a repeat is scheduled relative to completion, mirroring `Task.RepetitionMethod`.
enum RepetitionMethod: String, Codable, Hashable, Sendable {
    case fixed
    case startAfterCompletion = "start-after-completion"
    case dueAfterCompletion = "due-after-completion"
}

/// Field sets for task projection.
enum TaskFieldSet: String, CaseIterable, Sendable {
    case id, name, note, status, flagged, completed, dropped
    case dueDate, deferDate, completionDate, estimatedMinutes
    case projectId, projectName, parentId
    case tagIds, tagNames
    case hasChildren, sequential, repetitionRule, url
}

extension TaskFieldSet {
    /// Minimal fields returned by default.
    static let minimal: Set<TaskFieldSet> = [.id, .name, .status, .flagged, .completed, .dueDate]

    /// Standard fields for single-task views.
    static let standard: Set<TaskFieldSet> = minimal.union([
        .note, .deferDate, .projectName, .tagNames, .estimatedMinutes,
    ])

    /// All fields. Use sparingly.
    static let full: Set<TaskFieldSet> = Set(TaskFieldSet.allCases)

    /// Expensive fields that require extra lookups or may contain large data.
    static let expensive: Set<TaskFieldSet> = [.note, .tagIds, .parentId]
}
