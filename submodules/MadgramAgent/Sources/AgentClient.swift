import Foundation

public struct AgentToolSpec {
    public let name: String
    public let description: String
    public let schema: [String: Any]

    public init(name: String, description: String, schema: [String: Any]) {
        self.name = name
        self.description = description
        self.schema = schema
    }
}

public struct AgentModelInfo: Equatable {
    public let id: String
    public let displayName: String?

    public init(id: String, displayName: String?) {
        self.id = id
        self.displayName = displayName
    }
}

public enum AgentStopReason: Equatable {
    case endTurn
    case toolUse
    case maxTokens
    case refusal
    case pause
    case other(String)
}

public enum AgentStreamEvent {
    case textDelta(String)
    case thinking
    case toolCallStarted(name: String)
    case serverTool(name: String)
    case serverToolInput(name: String, input: [String: Any])
    case completed(AgentMessage, AgentStopReason)
}

public struct AgentError: LocalizedError {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        return self.message
    }
}

public protocol AgentClient {
    func listModels() async throws -> [AgentModelInfo]
    func stream(system: String, messages: [AgentMessage], tools: [AgentToolSpec], dropThinking: Bool) -> AsyncThrowingStream<AgentStreamEvent, Error>
}

public func makeAgentClient(settings: AgentSettings, apiKey: String, webTools: Bool? = nil) throws -> AgentClient {
    let provider = settings.provider
    guard let base = agentNormalizedBaseUrl(settings.currentBaseUrl) else {
        throw AgentError("Укажи адрес API в настройках агента.")
    }
    if provider.usesAnthropicProtocol {
        return AnthropicAgentClient(baseUrl: base, apiKey: apiKey, model: settings.currentModel, maxTokens: settings.maxTokens, apiVersion: provider == .anthropic ? "2026-10-21" : "2023-06-01", sendsBearer: provider != .anthropic, webTools: provider == .anthropic && (webTools ?? settings.allowWebSearch))
    } else {
        return OpenAIAgentClient(baseUrl: base, apiKey: apiKey, model: settings.currentModel)
    }
}

public func agentNormalizedBaseUrl(_ value: String) -> String? {
    var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return nil
    }
    if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
        trimmed = "https://" + trimmed
    }
    while trimmed.hasSuffix("/") {
        trimmed.removeLast()
    }
    guard let components = URLComponents(string: trimmed), components.host != nil else {
        return nil
    }
    if components.path.isEmpty {
        trimmed += "/v1"
    }
    return trimmed
}

private let agentUrlSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 120.0
    configuration.timeoutIntervalForResource = 900.0
    configuration.waitsForConnectivity = false
    return URLSession(configuration: configuration)
}()

private func agentJSONData(_ object: Any) -> Data? {
    return try? JSONSerialization.data(withJSONObject: object, options: [])
}

private func agentJSONString(_ object: Any) -> String {
    guard let data = agentJSONData(object), let string = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return string
}

private func agentParseObject(_ string: String) -> [String: Any]? {
    guard let data = string.data(using: .utf8) else {
        return nil
    }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

private func agentErrorMessage(status: Int, body: Data) -> String {
    if let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
        if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
            return "HTTP \(status): \(message)"
        }
        if let message = object["message"] as? String {
            return "HTTP \(status): \(message)"
        }
        if let error = object["error"] as? String {
            return "HTTP \(status): \(error)"
        }
    }
    let text = String(data: body.prefix(400), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    switch status {
    case 401, 403:
        return "HTTP \(status): ключ не подходит. Проверь API-ключ в настройках."
    case 404:
        return "HTTP 404: адрес или модель не найдены. Проверь адрес API и модель."
    case 429:
        return "HTTP 429: слишком много запросов или кончился лимит."
    default:
        return text.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(text)"
    }
}

private func agentPerform(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await agentUrlSession.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200 ..< 300).contains(status) else {
        throw AgentError(agentErrorMessage(status: status, body: data))
    }
    return data
}

private func agentOpenStream(_ request: URLRequest) async throws -> URLSession.AsyncBytes {
    let (bytes, response) = try await agentUrlSession.bytes(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200 ..< 300).contains(status) else {
        var body = Data()
        for try await byte in bytes {
            body.append(byte)
            if body.count > 16 * 1024 {
                break
            }
        }
        throw AgentError(agentErrorMessage(status: status, body: body))
    }
    return bytes
}

private func agentSSEPayload(_ line: Substring) -> Substring? {
    guard line.hasPrefix("data:") else {
        return nil
    }
    var payload = line.dropFirst(5)
    if payload.hasPrefix(" ") {
        payload = payload.dropFirst()
    }
    return payload
}

final class AnthropicAgentClient: AgentClient {
    private let baseUrl: String
    private let apiKey: String
    private let model: String
    private let maxTokens: Int
    private let apiVersion: String
    private let sendsBearer: Bool
    private let webTools: Bool

    init(baseUrl: String, apiKey: String, model: String, maxTokens: Int, apiVersion: String, sendsBearer: Bool, webTools: Bool) {
        self.sendsBearer = sendsBearer
        self.webTools = webTools
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.model = model
        self.maxTokens = maxTokens
        self.apiVersion = apiVersion
    }

    private func request(path: String) throws -> URLRequest {
        guard let url = URL(string: self.baseUrl + path) else {
            throw AgentError("Кривой адрес API.")
        }
        var request = URLRequest(url: url)
        request.setValue(self.apiKey, forHTTPHeaderField: "x-api-key")
        if self.sendsBearer {
            request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(self.apiVersion, forHTTPHeaderField: "anthropic-version")
        return request
    }

    func listModels() async throws -> [AgentModelInfo] {
        var result: [AgentModelInfo] = []
        var afterId: String?
        for _ in 0 ..< 10 {
            var path = "/models?limit=1000"
            if let afterId, let escaped = afterId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                path += "&after_id=\(escaped)"
            }
            let data = try await agentPerform(try self.request(path: path))
            guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let items = object["data"] as? [[String: Any]] else {
                throw AgentError("Не удалось разобрать список моделей.")
            }
            for item in items {
                if let id = item["id"] as? String {
                    result.append(AgentModelInfo(id: id, displayName: item["display_name"] as? String))
                }
            }
            if object["has_more"] as? Bool == true, let lastId = object["last_id"] as? String, lastId != afterId {
                afterId = lastId
            } else {
                break
            }
        }
        return result
    }

    private func encodeMessages(_ messages: [AgentMessage], dropThinking: Bool) -> [[String: Any]] {
        var result: [[String: Any]] = []
        func append(role: String, content: [[String: Any]]) {
            if content.isEmpty {
                return
            }
            if var last = result.last, last["role"] as? String == role, var lastContent = last["content"] as? [[String: Any]] {
                lastContent.append(contentsOf: content)
                last["content"] = lastContent
                result[result.count - 1] = last
            } else {
                result.append(["role": role, "content": content])
            }
        }
        for message in messages {
            switch message.role {
            case .user:
                var content: [[String: Any]] = []
                for image in message.images ?? [] {
                    content.append(["type": "image", "source": ["type": "base64", "media_type": image.mediaType, "data": image.base64]])
                }
                if !message.text.isEmpty {
                    content.append(["type": "text", "text": message.requestText])
                }
                append(role: "user", content: content)
            case .assistant:
                if !dropThinking, let blocks = message.anthropicBlocks, message.anthropicModel == self.model, let data = blocks.data(using: .utf8), let parsed = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]], !parsed.isEmpty {
                    append(role: "assistant", content: parsed)
                } else {
                    var content: [[String: Any]] = []
                    if !message.text.isEmpty {
                        content.append(["type": "text", "text": message.text])
                    }
                    for call in message.toolCalls {
                        content.append(["type": "tool_use", "id": call.id, "name": call.name, "input": call.argumentsObject])
                    }
                    append(role: "assistant", content: content)
                }
            case .tool:
                guard let toolCallId = message.toolCallId else {
                    continue
                }
                var block: [String: Any] = ["type": "tool_result", "tool_use_id": toolCallId, "content": message.text.isEmpty ? "(пусто)" : message.text]
                if let images = message.images, !images.isEmpty {
                    var parts: [[String: Any]] = [["type": "text", "text": message.text.isEmpty ? "(картинка)" : message.text]]
                    for image in images {
                        parts.append(["type": "image", "source": ["type": "base64", "media_type": image.mediaType, "data": image.base64]])
                    }
                    block["content"] = parts
                }
                if message.isError {
                    block["is_error"] = true
                }
                append(role: "user", content: [block])
            }
        }
        while let first = result.first, first["role"] as? String != "user" {
            result.removeFirst()
        }
        return result
    }

    func stream(system: String, messages: [AgentMessage], tools: [AgentToolSpec], dropThinking: Bool) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    var request = try self.request(path: "/messages")
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "accept")
                    var body: [String: Any] = [
                        "model": self.model,
                        "max_tokens": self.maxTokens,
                        "stream": true,
                        "messages": self.encodeMessages(messages, dropThinking: dropThinking)
                    ]
                    if !system.isEmpty {
                        body["system"] = system
                    }
                    var toolList: [[String: Any]] = tools.map { tool -> [String: Any] in
                        return ["name": tool.name, "description": tool.description, "input_schema": tool.schema]
                    }
                    if self.webTools {
                        toolList.append(["type": "web_search_20260209", "name": "web_search"])
                        toolList.append(["type": "web_fetch_20260209", "name": "web_fetch"])
                    }
                    if !toolList.isEmpty {
                        body["tools"] = toolList
                    }
                    request.httpBody = agentJSONData(body)

                    let bytes = try await agentOpenStream(request)
                    var blocks: [Int: [String: Any]] = [:]
                    var partialJson: [Int: String] = [:]
                    var stopReason: String?

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let payload = agentSSEPayload(Substring(line)), let event = agentParseObject(String(payload)) else {
                            continue
                        }
                        guard let type = event["type"] as? String else {
                            continue
                        }
                        switch type {
                        case "content_block_start":
                            guard let index = event["index"] as? Int, let block = event["content_block"] as? [String: Any] else {
                                break
                            }
                            blocks[index] = block
                            switch block["type"] as? String {
                            case "thinking", "redacted_thinking":
                                continuation.yield(.thinking)
                            case "tool_use":
                                partialJson[index] = ""
                                continuation.yield(.toolCallStarted(name: block["name"] as? String ?? ""))
                            case "server_tool_use":
                                partialJson[index] = ""
                                continuation.yield(.serverTool(name: block["name"] as? String ?? ""))
                            case "text":
                                if let text = block["text"] as? String, !text.isEmpty {
                                    continuation.yield(.textDelta(text))
                                }
                            default:
                                break
                            }
                        case "content_block_delta":
                            guard let index = event["index"] as? Int, let delta = event["delta"] as? [String: Any], var block = blocks[index] else {
                                break
                            }
                            switch delta["type"] as? String {
                            case "text_delta":
                                let text = delta["text"] as? String ?? ""
                                block["text"] = (block["text"] as? String ?? "") + text
                                if !text.isEmpty {
                                    continuation.yield(.textDelta(text))
                                }
                            case "thinking_delta":
                                block["thinking"] = (block["thinking"] as? String ?? "") + (delta["thinking"] as? String ?? "")
                            case "signature_delta":
                                block["signature"] = (block["signature"] as? String ?? "") + (delta["signature"] as? String ?? "")
                            case "input_json_delta":
                                partialJson[index, default: ""] += delta["partial_json"] as? String ?? ""
                            default:
                                break
                            }
                            blocks[index] = block
                        case "content_block_stop":
                            guard let index = event["index"] as? Int, var block = blocks[index] else {
                                break
                            }
                            if block["type"] as? String == "tool_use" || block["type"] as? String == "server_tool_use" {
                                let json = partialJson[index] ?? ""
                                let input = json.isEmpty ? [String: Any]() : (agentParseObject(json) ?? [String: Any]())
                                block["input"] = input
                                blocks[index] = block
                                if block["type"] as? String == "server_tool_use" {
                                    continuation.yield(.serverToolInput(name: block["name"] as? String ?? "", input: input))
                                }
                            }
                        case "message_delta":
                            if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                                stopReason = reason
                            }
                        case "error":
                            let error = event["error"] as? [String: Any]
                            throw AgentError(error?["message"] as? String ?? "Ошибка API.")
                        default:
                            break
                        }
                    }

                    var orderedBlocks: [[String: Any]] = []
                    var text = ""
                    var toolCalls: [AgentToolCall] = []
                    for index in blocks.keys.sorted() {
                        guard let block = blocks[index] else {
                            continue
                        }
                        switch block["type"] as? String {
                        case "text":
                            let value = block["text"] as? String ?? ""
                            if value.isEmpty {
                                continue
                            }
                            text += value
                            orderedBlocks.append(["type": "text", "text": value])
                        case "tool_use":
                            let input = block["input"] as? [String: Any] ?? [:]
                            let id = block["id"] as? String ?? UUID().uuidString
                            let name = block["name"] as? String ?? ""
                            toolCalls.append(AgentToolCall(id: id, name: name, arguments: agentJSONString(input)))
                            orderedBlocks.append(["type": "tool_use", "id": id, "name": name, "input": input])
                        default:
                            orderedBlocks.append(block)
                        }
                    }
                    let message = AgentMessage(role: .assistant, text: text, toolCalls: toolCalls, anthropicBlocks: agentJSONString(orderedBlocks), anthropicModel: self.model)
                    let reason: AgentStopReason
                    switch stopReason {
                    case "end_turn", "stop_sequence", .none:
                        reason = toolCalls.isEmpty ? .endTurn : .toolUse
                    case "tool_use":
                        reason = .toolUse
                    case "max_tokens", "model_context_window_exceeded":
                        reason = .maxTokens
                    case "refusal":
                        reason = .refusal
                    case "pause_turn":
                        reason = .pause
                    case let .some(value):
                        reason = .other(value)
                    }
                    continuation.yield(.completed(message, reason))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

final class OpenAIAgentClient: AgentClient {
    private let baseUrl: String
    private let apiKey: String
    private let model: String

    init(baseUrl: String, apiKey: String, model: String) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
        self.model = model
    }

    private func request(path: String) throws -> URLRequest {
        guard let url = URL(string: self.baseUrl + path) else {
            throw AgentError("Кривой адрес API.")
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(self.apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    func listModels() async throws -> [AgentModelInfo] {
        let data = try await agentPerform(try self.request(path: "/models"))
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let items = object["data"] as? [[String: Any]] else {
            throw AgentError("Не удалось разобрать список моделей.")
        }
        let sorted = items.sorted { lhs, rhs in
            let lhsCreated = (lhs["created"] as? NSNumber)?.int64Value ?? 0
            let rhsCreated = (rhs["created"] as? NSNumber)?.int64Value ?? 0
            if lhsCreated != rhsCreated {
                return lhsCreated > rhsCreated
            }
            return (lhs["id"] as? String ?? "") < (rhs["id"] as? String ?? "")
        }
        return sorted.compactMap { item in
            guard let id = item["id"] as? String else {
                return nil
            }
            return AgentModelInfo(id: id, displayName: item["name"] as? String)
        }
    }

    private func encodeMessages(system: String, _ messages: [AgentMessage]) -> [[String: Any]] {
        var result: [[String: Any]] = []
        if !system.isEmpty {
            result.append(["role": "system", "content": system])
        }
        var pendingToolImages: [AgentImage] = []
        func flushToolImages() {
            if pendingToolImages.isEmpty {
                return
            }
            var parts: [[String: Any]] = [["type": "text", "text": "Картинки из результатов инструментов выше:"]]
            for image in pendingToolImages {
                parts.append(["type": "image_url", "image_url": ["url": "data:\(image.mediaType);base64,\(image.base64)"]])
            }
            result.append(["role": "user", "content": parts])
            pendingToolImages = []
        }
        for message in messages {
            if message.role != .tool {
                flushToolImages()
            }
            switch message.role {
            case .user:
                if let images = message.images, !images.isEmpty {
                    var parts: [[String: Any]] = []
                    for image in images {
                        parts.append(["type": "image_url", "image_url": ["url": "data:\(image.mediaType);base64,\(image.base64)"]])
                    }
                    parts.append(["type": "text", "text": message.requestText.isEmpty ? "(картинка)" : message.requestText])
                    result.append(["role": "user", "content": parts])
                } else if !message.text.isEmpty {
                    result.append(["role": "user", "content": message.requestText])
                }
            case .assistant:
                if message.text.isEmpty && message.toolCalls.isEmpty {
                    continue
                }
                var item: [String: Any] = ["role": "assistant", "content": message.text.isEmpty ? NSNull() : message.text]
                if !message.toolCalls.isEmpty {
                    item["tool_calls"] = message.toolCalls.map { call -> [String: Any] in
                        return ["id": call.id, "type": "function", "function": ["name": call.name, "arguments": call.arguments]]
                    }
                }
                result.append(item)
            case .tool:
                guard let toolCallId = message.toolCallId else {
                    continue
                }
                result.append(["role": "tool", "tool_call_id": toolCallId, "content": message.text.isEmpty ? "(пусто)" : message.text])
                pendingToolImages.append(contentsOf: message.images ?? [])
            }
        }
        flushToolImages()
        return result
    }

    func stream(system: String, messages: [AgentMessage], tools: [AgentToolSpec], dropThinking: Bool) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    var request = try self.request(path: "/chat/completions")
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "content-type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "accept")
                    var body: [String: Any] = [
                        "model": self.model,
                        "stream": true,
                        "messages": self.encodeMessages(system: system, messages)
                    ]
                    if !tools.isEmpty {
                        body["tools"] = tools.map { tool -> [String: Any] in
                            return ["type": "function", "function": ["name": tool.name, "description": tool.description, "parameters": tool.schema]]
                        }
                    }
                    request.httpBody = agentJSONData(body)

                    let bytes = try await agentOpenStream(request)
                    var text = ""
                    var calls: [Int: (id: String, name: String, arguments: String)] = [:]
                    var finishReason: String?
                    var reportedThinking = false

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let payload = agentSSEPayload(Substring(line)) else {
                            continue
                        }
                        if payload == "[DONE]" {
                            break
                        }
                        guard let event = agentParseObject(String(payload)) else {
                            continue
                        }
                        if let error = event["error"] as? [String: Any] {
                            throw AgentError(error["message"] as? String ?? "Ошибка API.")
                        }
                        guard let choices = event["choices"] as? [[String: Any]], let choice = choices.first else {
                            continue
                        }
                        if let reason = choice["finish_reason"] as? String {
                            finishReason = reason
                        }
                        guard let delta = choice["delta"] as? [String: Any] else {
                            continue
                        }
                        if !reportedThinking, let reasoning = (delta["reasoning_content"] as? String) ?? (delta["reasoning"] as? String), !reasoning.isEmpty {
                            reportedThinking = true
                            continuation.yield(.thinking)
                        }
                        if let content = delta["content"] as? String, !content.isEmpty {
                            text += content
                            continuation.yield(.textDelta(content))
                        }
                        if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                            for call in toolCalls {
                                let index = call["index"] as? Int ?? calls.count
                                var current = calls[index] ?? (id: "", name: "", arguments: "")
                                if let id = call["id"] as? String, !id.isEmpty {
                                    current.id = id
                                }
                                if let function = call["function"] as? [String: Any] {
                                    if let name = function["name"] as? String, !name.isEmpty {
                                        if current.name.isEmpty {
                                            continuation.yield(.toolCallStarted(name: name))
                                        }
                                        current.name += name
                                    }
                                    if let arguments = function["arguments"] as? String {
                                        current.arguments += arguments
                                    }
                                }
                                calls[index] = current
                            }
                        }
                    }

                    let toolCalls = calls.keys.sorted().compactMap { index -> AgentToolCall? in
                        guard let call = calls[index], !call.name.isEmpty else {
                            return nil
                        }
                        return AgentToolCall(id: call.id.isEmpty ? "call_\(UUID().uuidString.prefix(12))" : call.id, name: call.name, arguments: call.arguments.isEmpty ? "{}" : call.arguments)
                    }
                    let message = AgentMessage(role: .assistant, text: text, toolCalls: toolCalls)
                    let reason: AgentStopReason
                    switch finishReason {
                    case "tool_calls", "function_call":
                        reason = .toolUse
                    case "length":
                        reason = .maxTokens
                    case "content_filter":
                        reason = .refusal
                    case "stop", .none:
                        reason = toolCalls.isEmpty ? .endTurn : .toolUse
                    case let .some(value):
                        reason = toolCalls.isEmpty ? .other(value) : .toolUse
                    }
                    continuation.yield(.completed(message, reason))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
