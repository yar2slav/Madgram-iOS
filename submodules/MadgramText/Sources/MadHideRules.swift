import Foundation

public final class MadHideRuleSet {
    public enum Rule {
        case substring(String)
        case regex(NSRegularExpression)
    }

    public struct LineError: Equatable {
        public let line: Int
        public let message: String
    }

    public let rules: [Rule]
    public let errors: [LineError]

    public var isEmpty: Bool {
        return self.rules.isEmpty
    }

    public init(source: String) {
        var rules: [Rule] = []
        var errors: [LineError] = []
        var seen = Set<String>()
        for (index, rawLine) in source.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || seen.contains(line) {
                continue
            }
            seen.insert(line)
            if let pattern = MadHideRuleSet.regexBody(line) {
                do {
                    rules.append(.regex(try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])))
                } catch {
                    errors.append(LineError(line: index + 1, message: (error as NSError).localizedDescription))
                }
            } else {
                rules.append(.substring(line))
            }
        }
        self.rules = rules
        self.errors = errors
    }

    private static func regexBody(_ line: String) -> String? {
        guard line.hasPrefix("/") else {
            return nil
        }
        if line.count >= 3 && line.hasSuffix("/i") {
            return String(line.dropFirst().dropLast(2))
        }
        if line.count >= 2 && line.hasSuffix("/") {
            let body = String(line.dropFirst().dropLast())
            return body.isEmpty ? nil : body
        }
        return nil
    }

    public func matches(_ text: String) -> Bool {
        if text.isEmpty {
            return false
        }
        for rule in self.rules {
            switch rule {
            case let .substring(value):
                if text.range(of: value, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    return true
                }
            case let .regex(expression):
                if expression.firstMatch(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) != nil {
                    return true
                }
            }
        }
        return false
    }

    private static let lock = NSLock()
    private static var cache: (source: String, set: MadHideRuleSet)?

    public static func cached(_ source: String) -> MadHideRuleSet {
        lock.lock()
        defer { lock.unlock() }
        if let cache, cache.source == source {
            return cache.set
        }
        let set = MadHideRuleSet(source: source)
        cache = (source, set)
        return set
    }
}
