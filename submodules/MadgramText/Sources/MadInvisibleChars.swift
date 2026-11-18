import Foundation

public enum MadInvisibleChars {
    private static let singles: Set<UInt32> = [0x00AD, 0x034F, 0x061C, 0x115F, 0x1160, 0x17B4, 0x17B5, 0x2800, 0x3164, 0xFEFF, 0xFFA0, 0x1D159]
    private static let ranges: [ClosedRange<UInt32>] = [
        0x180B ... 0x180F,
        0x200B ... 0x200F,
        0x2028 ... 0x202E,
        0x2060 ... 0x2064,
        0x2066 ... 0x206F,
        0xFE00 ... 0xFE0F,
        0x1D173 ... 0x1D17A,
        0xE0000 ... 0xE007F,
        0xE0100 ... 0xE01EF
    ]

    public static func isInvisible(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isWhitespace {
            return true
        }
        let value = scalar.value
        if singles.contains(value) {
            return true
        }
        return ranges.contains(where: { $0.contains(value) })
    }

    public static func isFullyInvisible(_ text: String) -> Bool {
        return text.unicodeScalars.allSatisfy(isInvisible)
    }

    public static func label(_ scalar: Unicode.Scalar) -> String {
        return String(format: "U+%04X", scalar.value)
    }

    public static func visualize(_ text: String) -> String? {
        guard !text.isEmpty, isFullyInvisible(text) else {
            return nil
        }
        return text.unicodeScalars.map { "⟨" + label($0) + "⟩" }.joined()
    }
}
