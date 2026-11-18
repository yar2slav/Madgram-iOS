import Foundation
import UIKit

struct AgentMarkdownStyle {
    let fontSize: CGFloat
    let textColor: UIColor
    let secondaryColor: UIColor
    let linkColor: UIColor
    let codeBackground: UIColor
}

enum AgentMarkdown {
    static func render(_ text: String, style: AgentMarkdownStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = UIFont.systemFont(ofSize: style.fontSize)
        let codeFont = UIFont.monospacedSystemFont(ofSize: style.fontSize - 2.0, weight: .regular)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.0
        paragraph.paragraphSpacing = 6.0

        var inCodeBlock = false
        var codeLines: [String] = []
        let lines = text.components(separatedBy: "\n")

        func appendNewlineIfNeeded() {
            if result.length > 0 {
                result.append(NSAttributedString(string: "\n", attributes: [.font: baseFont, .paragraphStyle: paragraph]))
            }
        }

        func flushCode() {
            appendNewlineIfNeeded()
            let codeParagraph = NSMutableParagraphStyle()
            codeParagraph.firstLineHeadIndent = 8.0
            codeParagraph.headIndent = 8.0
            codeParagraph.tailIndent = -8.0
            codeParagraph.paragraphSpacing = 6.0
            codeParagraph.paragraphSpacingBefore = 2.0
            let body = codeLines.joined(separator: "\n")
            result.append(NSAttributedString(string: body.isEmpty ? " " : body, attributes: [
                .font: codeFont,
                .foregroundColor: style.textColor,
                .backgroundColor: style.codeBackground,
                .paragraphStyle: codeParagraph
            ]))
            codeLines.removeAll()
        }

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    flushCode()
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            var line = rawLine
            var font = baseFont
            var color = style.textColor
            var lineParagraph = paragraph
            var prefix = ""

            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                if level <= 6 && trimmed.dropFirst(level).hasPrefix(" ") {
                    line = String(trimmed.dropFirst(level + 1))
                    let size: CGFloat = level == 1 ? style.fontSize + 4.0 : (level == 2 ? style.fontSize + 2.0 : style.fontSize + 1.0)
                    font = UIFont.systemFont(ofSize: size, weight: .bold)
                }
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                let indent = CGFloat(rawLine.prefix(while: { $0 == " " }).count / 2) * 14.0
                line = String(trimmed.dropFirst(2))
                prefix = "•\t"
                let listParagraph = NSMutableParagraphStyle()
                listParagraph.lineSpacing = 2.0
                listParagraph.paragraphSpacing = 3.0
                listParagraph.firstLineHeadIndent = indent
                listParagraph.headIndent = indent + 16.0
                listParagraph.tabStops = [NSTextTab(textAlignment: .left, location: indent + 16.0)]
                lineParagraph = listParagraph
            } else if let match = trimmed.range(of: "^[0-9]{1,3}[.)] ", options: .regularExpression) {
                let number = String(trimmed[match]).trimmingCharacters(in: .whitespaces)
                line = String(trimmed[match.upperBound...])
                prefix = "\(number)\t"
                let listParagraph = NSMutableParagraphStyle()
                listParagraph.lineSpacing = 2.0
                listParagraph.paragraphSpacing = 3.0
                listParagraph.headIndent = 22.0
                listParagraph.tabStops = [NSTextTab(textAlignment: .left, location: 22.0)]
                lineParagraph = listParagraph
            } else if trimmed.hasPrefix(">") {
                line = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                color = style.secondaryColor
                let quoteParagraph = NSMutableParagraphStyle()
                quoteParagraph.firstLineHeadIndent = 10.0
                quoteParagraph.headIndent = 10.0
                quoteParagraph.paragraphSpacing = 4.0
                lineParagraph = quoteParagraph
            } else if trimmed == "---" || trimmed == "***" {
                appendNewlineIfNeeded()
                result.append(NSAttributedString(string: "———", attributes: [.font: baseFont, .foregroundColor: style.secondaryColor, .paragraphStyle: paragraph]))
                continue
            }

            appendNewlineIfNeeded()
            if !prefix.isEmpty {
                result.append(NSAttributedString(string: prefix, attributes: [.font: baseFont, .foregroundColor: style.secondaryColor, .paragraphStyle: lineParagraph]))
            }
            result.append(self.inline(line, font: font, color: color, codeFont: codeFont, style: style, paragraph: lineParagraph))
        }
        if inCodeBlock {
            flushCode()
        }
        return result
    }

    private static func inline(_ text: String, font: UIFont, color: UIColor, codeFont: UIFont, style: AgentMarkdownStyle, paragraph: NSParagraphStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        guard let parsed = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)) else {
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
        }
        for run in parsed.runs {
            let string = String(parsed[run.range].characters)
            var runFont = font
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color, .paragraphStyle: paragraph]
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) {
                    runFont = codeFont
                    attributes[.backgroundColor] = style.codeBackground
                } else {
                    var traits: UIFontDescriptor.SymbolicTraits = []
                    if intent.contains(.stronglyEmphasized) {
                        traits.insert(.traitBold)
                    }
                    if intent.contains(.emphasized) {
                        traits.insert(.traitItalic)
                    }
                    if !traits.isEmpty, let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits)) {
                        runFont = UIFont(descriptor: descriptor, size: font.pointSize)
                    }
                }
                if intent.contains(.strikethrough) {
                    attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                }
            }
            if let link = run.link {
                attributes[.link] = link
                attributes[.foregroundColor] = style.linkColor
            }
            attributes[.font] = runFont
            result.append(NSAttributedString(string: string, attributes: attributes))
        }
        return result
    }
}
