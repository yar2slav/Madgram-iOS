import Foundation
import TelegramCore

public struct MadTextReplacement: Equatable {
    public var range: NSRange
    public var value: String

    public init(range: NSRange, value: String) {
        self.range = range
        self.value = value
    }
}

public enum MadTextEditing {
    public static func apply(_ replacements: [MadTextReplacement], text: String, entities: [MessageTextEntity]) -> (text: String, entities: [MessageTextEntity]) {
        if replacements.isEmpty {
            return (text, entities)
        }
        let result = NSMutableString(string: text)
        var entities = entities
        var lastStart = Int.max
        for replacement in replacements.sorted(by: { $0.range.location > $1.range.location }) {
            let start = replacement.range.location
            let end = start + replacement.range.length
            if start < 0 || end > lastStart || end > result.length {
                continue
            }
            lastStart = start
            let newLength = (replacement.value as NSString).length
            let delta = newLength - replacement.range.length
            result.replaceCharacters(in: replacement.range, with: replacement.value)
            func map(_ position: Int) -> Int {
                if position <= start {
                    return position
                } else if position >= end {
                    return position + delta
                } else {
                    return start + min(position - start, newLength)
                }
            }
            entities = entities.compactMap { entity in
                let lower = map(entity.range.lowerBound)
                let upper = map(entity.range.upperBound)
                if upper <= lower {
                    return nil
                }
                return MessageTextEntity(range: lower ..< upper, type: entity.type)
            }
        }
        return (result as String, entities)
    }

    public static func removing(_ ranges: [NSRange], text: String, entities: [MessageTextEntity]) -> (text: String, entities: [MessageTextEntity]) {
        return apply(ranges.map { MadTextReplacement(range: $0, value: "") }, text: text, entities: entities)
    }

    public static func mergedRanges(_ ranges: [NSRange]) -> [NSRange] {
        var result: [NSRange] = []
        for range in ranges.sorted(by: { $0.location < $1.location }) {
            if let last = result.last, range.location <= last.location + last.length {
                let upper = max(last.location + last.length, range.location + range.length)
                result[result.count - 1] = NSRange(location: last.location, length: upper - last.location)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
