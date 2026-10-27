import SwiftUI

/// Represents a distinct markdown block for rich rendering.
enum MarkdownBlock: Identifiable, Equatable {
    case h1(String)
    case h2(String)
    case h3(String)
    case quote(String)
    case bullet(String)
    case numbered(Int, String)
    case code(String, String) // (language, code)
    case divider
    case paragraph(String)

    var id: String {
        switch self {
        case .h1(let s): return "h1_\(s.hashValue)"
        case .h2(let s): return "h2_\(s.hashValue)"
        case .h3(let s): return "h3_\(s.hashValue)"
        case .quote(let s): return "q_\(s.hashValue)"
        case .bullet(let s): return "b_\(s.hashValue)"
        case .numbered(let n, let s): return "n_\(n)_\(s.hashValue)"
        case .code(let l, let c): return "c_\(l)_\(c.hashValue)"
        case .divider: return "div_\(UUID().uuidString)"
        case .paragraph(let s): return "p_\(s.hashValue)"
        }
    }
}

/// Parses raw markdown into structured blocks.
enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.components(separatedBy: .newlines)
        var i = 0
        var inCode = false
        var codeLang = ""
        var codeBuffer: [String] = []

        while i < lines.count {
            let rawLine = lines[i]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if inCode {
                if trimmed.hasPrefix("```") {
                    inCode = false
                    blocks.append(.code(codeLang, codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                    codeLang = ""
                } else {
                    codeBuffer.append(rawLine)
                }
                i += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                inCode = true
                codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeBuffer.removeAll()
                i += 1
                continue
            }

            if trimmed.isEmpty {
                i += 1
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                i += 1
                continue
            }

            if trimmed.hasPrefix("### ") {
                blocks.append(.h3(String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            if trimmed.hasPrefix("#### ") {
                blocks.append(.h3(String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            if trimmed.hasPrefix("##### ") {
                blocks.append(.h3(String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            if trimmed.hasPrefix("## ") {
                blocks.append(.h2(String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            if trimmed.hasPrefix("# ") {
                blocks.append(.h1(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            if trimmed.hasPrefix("> ") || trimmed == ">" {
                var quoteLines = [String(trimmed.dropFirst(trimmed.hasPrefix("> ") ? 2 : 1))]
                while i + 1 < lines.count {
                    let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if next.hasPrefix("> ") {
                        quoteLines.append(String(next.dropFirst(2)))
                        i += 1
                    } else if !next.isEmpty && !next.hasPrefix("#") && !next.hasPrefix("-") && !next.hasPrefix("*") && !next.hasPrefix("```") && next != "---" && !isNumbered(next) {
                        quoteLines.append(next)
                        i += 1
                    } else {
                        break
                    }
                }
                blocks.append(.quote(quoteLines.joined(separator: " ")))
                i += 1
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                i += 1
                continue
            }

            if let (num, content) = parseNumbered(trimmed) {
                blocks.append(.numbered(num, content))
                i += 1
                continue
            }

            // Paragraph: gather text until a new block or empty line
            var paraLines = [trimmed]
            while i + 1 < lines.count {
                let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if next.isEmpty || next.hasPrefix("#") || next.hasPrefix("-") || next.hasPrefix("*") || next.hasPrefix(">") || next.hasPrefix("```") || next == "---" || isNumbered(next) {
                    break
                }
                paraLines.append(next)
                i += 1
            }
            blocks.append(.paragraph(paraLines.joined(separator: " ")))
            i += 1
        }

        if inCode {
            blocks.append(.code(codeLang, codeBuffer.joined(separator: "\n")))
        }

        return blocks
    }

    private static func isNumbered(_ line: String) -> Bool {
        let p = line.prefix(while: { $0.isNumber })
        return !p.isEmpty && line.dropFirst(p.count).hasPrefix(". ")
    }

    private static func parseNumbered(_ line: String) -> (Int, String)? {
        let p = line.prefix(while: { $0.isNumber })
        guard !p.isEmpty, line.dropFirst(p.count).hasPrefix(". ") else { return nil }
        let num = Int(p) ?? 1
        let text = String(line.dropFirst(p.count + 2)).trimmingCharacters(in: .whitespaces)
        return (num, text)
    }
}

/// Renders a full structured markdown document with proper spacing, formatting, and highlights.
struct MarkdownRendererView: View {
    let markdown: String

    var body: some View {
        let blocks = MarkdownParser.parse(markdown)

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .h1(let text):
            Text(inline(text))
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.primary)
                .padding(.top, 6)
                .padding(.bottom, 2)

        case .h2(let text):
            Text(inline(text))
                .font(.headline.weight(.bold))
                .foregroundStyle(Palette.accent)
                .padding(.top, 6)
                .padding(.bottom, 2)

        case .h3(let text):
            Text(inline(text))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .padding(.top, 4)
                .padding(.bottom, 1)

        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Palette.accent)
                    .frame(width: 3)
                Text(inline(text))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.vertical, 2)

        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 5, height: 5)
                    .padding(.top, 6)
                Text(inline(text))
                    .font(.callout)
                    .lineSpacing(2)
            }
            .padding(.leading, 4)
            .padding(.vertical, 1)

        case .numbered(let num, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(num).")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minWidth: 18, alignment: .trailing)
                Text(inline(text))
                    .font(.callout)
                    .lineSpacing(2)
            }
            .padding(.leading, 2)
            .padding(.vertical, 1)

        case .code(let lang, let code):
            VStack(alignment: .leading, spacing: 0) {
                if !lang.isEmpty {
                    HStack {
                        Text(lang.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    Divider()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(10)
                        .textSelection(.enabled)
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .padding(.vertical, 3)

        case .divider:
            Divider()
                .padding(.vertical, 4)

        case .paragraph(let text):
            Text(inline(text))
                .font(.callout)
                .lineSpacing(2)
                .padding(.vertical, 1)
        }
    }

    private func inline(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let attr = try? AttributedString(markdown: text, options: options) {
            return attr
        }
        return AttributedString(text)
    }
}
