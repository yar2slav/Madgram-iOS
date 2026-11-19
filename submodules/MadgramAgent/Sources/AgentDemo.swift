#if DEBUG
import Foundation

public enum AgentDemoScript {
    public enum Step {
        case thinking(seconds: Double)
        case tools([(name: String, arguments: String, running: String, done: String, seconds: Double)])
        case text(String, charactersPerSecond: Double)
    }

    public struct Exchange {
        public var match: String
        public var steps: [Step]

        public init(match: String, steps: [Step]) {
            self.match = match
            self.steps = steps
        }
    }

    public static var exchanges: [Exchange] = []
    public static var runningTitles: [String: String] = [:]

    public static var isActive: Bool {
        return !self.exchanges.isEmpty
    }

    static func script(for text: String) -> [Step]? {
        let lowered = text.lowercased()
        return self.exchanges.first(where: { lowered.contains($0.match.lowercased()) })?.steps ?? self.exchanges.last?.steps
    }
}

extension AgentRunner {
    func runDemoScript(_ steps: [AgentDemoScript.Step]) async -> Bool {
        for step in steps {
            if Task.isCancelled {
                return false
            }
            switch step {
            case let .thinking(seconds):
                self.demoSetThinking(true)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                self.demoSetThinking(false)
            case let .tools(tools):
                let calls = tools.map { tool in AgentToolCall(id: UUID().uuidString, name: tool.name, arguments: tool.arguments) }
                for (call, tool) in zip(calls, tools) {
                    AgentDemoScript.runningTitles[call.id] = tool.running
                }
                self.demoAppend(AgentMessage(role: .assistant, text: "", toolCalls: calls))
                for (call, tool) in zip(calls, tools) {
                    self.demoSetActiveToolCall(call)
                    try? await Task.sleep(nanoseconds: UInt64(tool.seconds * 1_000_000_000))
                    self.demoAppend(AgentMessage(role: .tool, text: "ok", toolCallId: call.id, toolTitle: tool.done))
                    self.demoSetActiveToolCall(nil)
                }
            case let .text(text, charactersPerSecond):
                var index = text.startIndex
                let chunk = 3
                while index < text.endIndex {
                    let next = text.index(index, offsetBy: chunk, limitedBy: text.endIndex) ?? text.endIndex
                    self.demoStream(String(text[index ..< next]))
                    index = next
                    try? await Task.sleep(nanoseconds: UInt64(Double(chunk) / charactersPerSecond * 1_000_000_000))
                }
                self.demoCommitStream()
            }
        }
        return true
    }
}
#endif
