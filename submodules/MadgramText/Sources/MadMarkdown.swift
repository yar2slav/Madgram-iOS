import Foundation
import TelegramCore

public enum MadMarkdown {
    public static func parse(_ source: String) -> (text: String, entities: [MessageTextEntity]) {
        var out = ""
        var entities: [MessageTextEntity] = []
        var isFirst = true
        func separator() {
            if !isFirst {
                out += "\n"
            }
            isFirst = false
        }

        let lines = source.components(separatedBy: "\n")
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                index += 1
                separator()
                let start = out.utf16.count
                out += codeLines.joined(separator: "\n")
                if out.utf16.count > start {
                    entities.append(MessageTextEntity(range: start ..< out.utf16.count, type: .Pre(language: language.isEmpty ? nil : language)))
                }
                continue
            }
            if trimmed.hasPrefix(">") && !trimmed.hasPrefix(">>") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else {
                        break
                    }
                    var value = current.dropFirst()
                    if value.hasPrefix(" ") {
                        value = value.dropFirst()
                    }
                    quoteLines.append(String(value))
                    index += 1
                }
                separator()
                let start = out.utf16.count
                appendInline(quoteLines.joined(separator: "\n"), out: &out, entities: &entities)
                if out.utf16.count > start {
                    entities.append(MessageTextEntity(range: start ..< out.utf16.count, type: .BlockQuote(isCollapsed: false)))
                }
                continue
            }
            separator()
            if let heading = headingContent(trimmed) {
                let start = out.utf16.count
                appendInline(heading, out: &out, entities: &entities)
                if out.utf16.count > start {
                    entities.append(MessageTextEntity(range: start ..< out.utf16.count, type: .Bold))
                }
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let indent = String(line.prefix(while: { $0 == " " }))
                out += indent + "• "
                appendInline(String(trimmed.dropFirst(2)), out: &out, entities: &entities)
            } else {
                appendInline(line, out: &out, entities: &entities)
            }
            index += 1
        }
        return (out, entities.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }))
    }

    private static func headingContent(_ line: String) -> String? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard !hashes.isEmpty, hashes.count <= 6 else {
            return nil
        }
        let rest = line.dropFirst(hashes.count)
        guard rest.hasPrefix(" ") else {
            return nil
        }
        return String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func find(_ marker: [Character], in chars: [Character], from: Int) -> Int? {
        guard !marker.isEmpty, from <= chars.count - marker.count else {
            return nil
        }
        var index = from
        while index <= chars.count - marker.count {
            if Array(chars[index ..< index + marker.count]) == marker {
                return index
            }
            index += 1
        }
        return nil
    }

    private static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character else {
            return false
        }
        return character.isLetter || character.isNumber
    }

    private static func appendInline(_ source: String, out: inout String, entities: inout [MessageTextEntity]) {
        let chars = Array(source)
        var index = 0
        var plain = ""
        func flush() {
            out += plain
            plain = ""
        }
        func wrap(_ content: String, type: MessageTextEntityType) {
            flush()
            let start = out.utf16.count
            appendInline(content, out: &out, entities: &entities)
            if out.utf16.count > start {
                entities.append(MessageTextEntity(range: start ..< out.utf16.count, type: type))
            }
        }
        let pairs: [(String, MessageTextEntityType)] = [("**", .Bold), ("__", .Bold), ("~~", .Strikethrough), ("||", .Spoiler)]
        outer: while index < chars.count {
            let character = chars[index]
            if character == "`" {
                if let end = find(["`"], in: chars, from: index + 1), end > index + 1 {
                    flush()
                    let start = out.utf16.count
                    out += String(chars[index + 1 ..< end])
                    entities.append(MessageTextEntity(range: start ..< out.utf16.count, type: .Code))
                    index = end + 1
                    continue
                }
            }
            for (marker, type) in pairs {
                let markerChars = Array(marker)
                if index + 2 <= chars.count, Array(chars[index ..< index + 2]) == markerChars, index + 2 < chars.count, chars[index + 2] != " " {
                    if let end = find(markerChars, in: chars, from: index + 3), chars[end - 1] != " " {
                        wrap(String(chars[index + 2 ..< end]), type: type)
                        index = end + 2
                        continue outer
                    }
                }
            }
            if character == "*" || character == "_" {
                let previous: Character? = index > 0 ? chars[index - 1] : nil
                if index + 1 < chars.count, chars[index + 1] != " ", chars[index + 1] != character, !isWordCharacter(previous) {
                    if let end = find([character], in: chars, from: index + 2), chars[end - 1] != " " {
                        let next: Character? = end + 1 < chars.count ? chars[end + 1] : nil
                        if !isWordCharacter(next) {
                            wrap(String(chars[index + 1 ..< end]), type: .Italic)
                            index = end + 1
                            continue
                        }
                    }
                }
            }
            if character == "[" {
                if let close = find(["]", "("], in: chars, from: index + 1), let end = find([")"], in: chars, from: close + 2) {
                    let url = String(chars[close + 2 ..< end]).trimmingCharacters(in: .whitespaces)
                    if url.contains("://") || url.hasPrefix("tg:") || url.hasPrefix("mailto:") {
                        wrap(String(chars[index + 1 ..< close]), type: .TextUrl(url: url))
                        index = end + 1
                        continue
                    }
                }
            }
            plain.append(character)
            index += 1
        }
        flush()
    }
}
