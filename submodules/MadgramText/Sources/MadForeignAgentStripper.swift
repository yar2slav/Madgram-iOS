import Foundation
import TelegramCore

public enum MadForeignAgentStripper {
    private static let expressions: [NSRegularExpression] = [
        "(?:НАСТОЯЩИЙ|ДАННЫЙ)\\s+МАТЕРИАЛ[\\s\\S]{0,80}?ПРОИЗВЕД[ЕЁ]Н[\\s\\S]{0,600}?ИНОСТРАНН\\w*\\s+(?:АГЕНТ|СРЕДСТВ)\\w*[^.\\n]*(?:\\.|$)(?:\\s*18\\s*\\+)?",
        "(?:ДАННОЕ|НАСТОЯЩЕЕ)\\s+СООБЩЕНИЕ[\\s\\S]{0,80}?(?:СОЗДАНО|РАСПРОСТРАНЕНО)[\\s\\S]{0,600}?ИНОСТРАНН\\w*\\s+(?:АГЕНТ|СРЕДСТВ)\\w*[^.\\n]*(?:\\.|$)(?:\\s*18\\s*\\+)?",
        "^[ \\t]*\\*+[^\\n]*(?:Минюст|иноагент|иностранн\\w*\\s+агент|экстремист|террорист|нежелательн)[^\\n]*$",
        "^[ \\t]*18\\s*\\+[ \\t]*$"
    ].map { pattern in
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines])
    }

    private static func isSpace(_ character: unichar) -> Bool {
        return character == 0x20 || character == 0x0a || character == 0x09 || character == 0x0d || character == 0xa0
    }

    private static func mayContain(_ text: String) -> Bool {
        return text.contains("18") || text.contains("*") || text.range(of: "агент", options: .caseInsensitive) != nil || text.range(of: "средств", options: .caseInsensitive) != nil
    }

    public static func ranges(in text: String) -> [NSRange] {
        if !mayContain(text) {
            return []
        }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        var found: [NSRange] = []
        for expression in expressions {
            for match in expression.matches(in: text, options: [], range: full) where match.range.length > 0 {
                found.append(match.range)
            }
        }
        if found.isEmpty {
            return []
        }
        var expanded: [NSRange] = []
        for range in MadTextEditing.mergedRanges(found) {
            var start = range.location
            var end = range.location + range.length
            while end < ns.length && isSpace(ns.character(at: end)) {
                end += 1
            }
            if end == ns.length {
                while start > 0 && isSpace(ns.character(at: start - 1)) {
                    start -= 1
                }
            }
            expanded.append(NSRange(location: start, length: end - start))
        }
        return MadTextEditing.mergedRanges(expanded)
    }

    public static func strip(text: String, entities: [MessageTextEntity]) -> (text: String, entities: [MessageTextEntity])? {
        let ranges = self.ranges(in: text)
        if ranges.isEmpty {
            return nil
        }
        let result = MadTextEditing.removing(ranges, text: text, entities: entities)
        if result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return result
    }
}
