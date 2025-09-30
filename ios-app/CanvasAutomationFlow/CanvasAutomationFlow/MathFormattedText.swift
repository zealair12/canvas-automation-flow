//
//  MathFormattedText.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-22.
//

import SwiftUI
import UIKit
import WebKit

// Enhanced FormattedText component with native iOS math rendering
struct MathFormattedText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(parseContent(text), id: \.id) { block in
                switch block.type {
                case .math:
                    IosMathView(latex: block.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .text:
                    // SmartMarkdownText handles headers, bold, italic, etc.
                    SmartMarkdownText(text: block.content)
                case .bulletList:
                    ForEach(block.listItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .fontWeight(.bold)
                            if let attributedString = try? AttributedString(markdown: item) {
                                Text(attributedString)
                            } else {
                                Text(item)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

// Content parsing structures
enum ContentBlockType {
    case text, math, bulletList
}

struct ContentBlock {
    let id = UUID()
    let type: ContentBlockType
    let content: String
    let listItems: [String]
    
    init(type: ContentBlockType, content: String, listItems: [String] = []) {
        self.type = type
        self.content = content
        self.listItems = listItems
    }
}

// Native iOS Math renderer using simplified LaTeX conversion
struct IosMathView: View {
    let latex: String
    
    var body: some View {
        Text(formatMathForDisplay(latex))
            .font(.system(size: 18, weight: .regular, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.vertical, 4)
    }
    
    private func formatMathForDisplay(_ latex: String) -> String {
        // Simplified LaTeX to readable text conversion
        var expression = latex
        
        // Handle common LaTeX commands
        expression = expression.replacingOccurrences(of: "\\frac{", with: "(")
        expression = expression.replacingOccurrences(of: "}{", with: ")/(")
        expression = expression.replacingOccurrences(of: "\\sqrt{", with: "√(")
        expression = expression.replacingOccurrences(of: "\\pi", with: "π")
        expression = expression.replacingOccurrences(of: "\\alpha", with: "α")
        expression = expression.replacingOccurrences(of: "\\beta", with: "β")
        expression = expression.replacingOccurrences(of: "\\gamma", with: "γ")
        expression = expression.replacingOccurrences(of: "\\delta", with: "δ")
        expression = expression.replacingOccurrences(of: "\\theta", with: "θ")
        expression = expression.replacingOccurrences(of: "\\lambda", with: "λ")
        expression = expression.replacingOccurrences(of: "\\mu", with: "μ")
        expression = expression.replacingOccurrences(of: "\\sigma", with: "σ")
        expression = expression.replacingOccurrences(of: "\\tau", with: "τ")
        expression = expression.replacingOccurrences(of: "\\phi", with: "φ")
        expression = expression.replacingOccurrences(of: "\\omega", with: "ω")
        expression = expression.replacingOccurrences(of: "\\infty", with: "∞")
        expression = expression.replacingOccurrences(of: "\\sum", with: "∑")
        expression = expression.replacingOccurrences(of: "\\int", with: "∫")
        expression = expression.replacingOccurrences(of: "\\partial", with: "∂")
        expression = expression.replacingOccurrences(of: "\\nabla", with: "∇")
        expression = expression.replacingOccurrences(of: "\\leq", with: "≤")
        expression = expression.replacingOccurrences(of: "\\geq", with: "≥")
        expression = expression.replacingOccurrences(of: "\\neq", with: "≠")
        expression = expression.replacingOccurrences(of: "\\approx", with: "≈")
        expression = expression.replacingOccurrences(of: "\\equiv", with: "≡")
        expression = expression.replacingOccurrences(of: "\\rightarrow", with: "→")
        expression = expression.replacingOccurrences(of: "\\leftarrow", with: "←")
        expression = expression.replacingOccurrences(of: "\\pm", with: "±")
        expression = expression.replacingOccurrences(of: "\\times", with: "×")
        expression = expression.replacingOccurrences(of: "\\div", with: "÷")
        expression = expression.replacingOccurrences(of: "\\cdot", with: "·")
        expression = expression.replacingOccurrences(of: "\\in", with: "∈")
        expression = expression.replacingOccurrences(of: "\\notin", with: "∉")
        expression = expression.replacingOccurrences(of: "\\subset", with: "⊂")
        expression = expression.replacingOccurrences(of: "\\supset", with: "⊃")
        expression = expression.replacingOccurrences(of: "\\cup", with: "∪")
        expression = expression.replacingOccurrences(of: "\\cap", with: "∩")
        expression = expression.replacingOccurrences(of: "\\emptyset", with: "∅")
        expression = expression.replacingOccurrences(of: "\\forall", with: "∀")
        expression = expression.replacingOccurrences(of: "\\exists", with: "∃")
        
        // Handle superscripts
        expression = expression.replacingOccurrences(of: "^0", with: "⁰")
        expression = expression.replacingOccurrences(of: "^1", with: "¹")
        expression = expression.replacingOccurrences(of: "^2", with: "²")
        expression = expression.replacingOccurrences(of: "^3", with: "³")
        expression = expression.replacingOccurrences(of: "^4", with: "⁴")
        expression = expression.replacingOccurrences(of: "^5", with: "⁵")
        expression = expression.replacingOccurrences(of: "^6", with: "⁶")
        expression = expression.replacingOccurrences(of: "^7", with: "⁷")
        expression = expression.replacingOccurrences(of: "^8", with: "⁸")
        expression = expression.replacingOccurrences(of: "^9", with: "⁹")
        
        // Handle subscripts
        expression = expression.replacingOccurrences(of: "_0", with: "₀")
        expression = expression.replacingOccurrences(of: "_1", with: "₁")
        expression = expression.replacingOccurrences(of: "_2", with: "₂")
        expression = expression.replacingOccurrences(of: "_3", with: "₃")
        expression = expression.replacingOccurrences(of: "_4", with: "₄")
        expression = expression.replacingOccurrences(of: "_5", with: "₅")
        expression = expression.replacingOccurrences(of: "_6", with: "₆")
        expression = expression.replacingOccurrences(of: "_7", with: "₇")
        expression = expression.replacingOccurrences(of: "_8", with: "₈")
        expression = expression.replacingOccurrences(of: "_9", with: "₉")
        
        // Clean up braces
        expression = expression.replacingOccurrences(of: "{", with: "")
        expression = expression.replacingOccurrences(of: "}", with: "")
        
        return expression
    }
}

// Content parser
private func parseContent(_ text: String) -> [ContentBlock] {
    let lines = text.components(separatedBy: .newlines)
    var blocks: [ContentBlock] = []
    var currentBulletItems: [String] = []
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        if trimmed.isEmpty {
            // Add any pending bullet list
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            continue
        }
        
        // Check for headers - but keep them as text for SmartMarkdownText to handle
        if trimmed.hasPrefix("#") && (trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ")) {
            // Headers should be handled by SmartMarkdownText, so treat as regular text
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            blocks.append(ContentBlock(type: .text, content: trimmed))
        }
        // Check for math (display equations)
        else if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") {
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            let mathContent = String(trimmed.dropFirst(2).dropLast(2))
            blocks.append(ContentBlock(type: .math, content: mathContent))
        }
        // Check for inline math
        else if trimmed.contains("$") {
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            // Extract math parts
            let parts = extractMathParts(from: trimmed)
            for part in parts {
                if part.isMath {
                    blocks.append(ContentBlock(type: .math, content: part.content))
                } else {
                    blocks.append(ContentBlock(type: .text, content: part.content))
                }
            }
        }
        // Check for bullet points
        else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let bulletContent = String(trimmed.dropFirst(2))
            currentBulletItems.append(bulletContent)
        }
        // Regular text
        else {
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            blocks.append(ContentBlock(type: .text, content: trimmed))
        }
    }
    
    // Add any remaining bullet items
    if !currentBulletItems.isEmpty {
        blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
    }
    
    return blocks
}

struct MathPart {
    let content: String
    let isMath: Bool
}

private func extractMathParts(from text: String) -> [MathPart] {
    var parts: [MathPart] = []
    var currentText = text
    
    while let dollarRange = currentText.range(of: "$") {
        // Add text before the dollar sign
        if dollarRange.lowerBound > currentText.startIndex {
            let beforeText = String(currentText[..<dollarRange.lowerBound])
            if !beforeText.isEmpty {
                parts.append(MathPart(content: beforeText, isMath: false))
            }
        }
        
        // Find the closing dollar sign
        let afterDollar = currentText[dollarRange.upperBound...]
        if let closingRange = afterDollar.range(of: "$") {
            let mathContent = String(afterDollar[..<closingRange.lowerBound])
            parts.append(MathPart(content: mathContent, isMath: true))
            currentText = String(afterDollar[closingRange.upperBound...])
        } else {
            // No closing dollar, treat as regular text
            parts.append(MathPart(content: String(currentText[dollarRange.lowerBound...]), isMath: false))
            break
        }
    }
    
    // Add any remaining text
    if !currentText.isEmpty {
        parts.append(MathPart(content: currentText, isMath: false))
    }
    
    return parts
}

// Modern text formatting component with multiple rendering options
struct ModernFormattedText: View {
    let text: String
    @State private var renderingMode: TextRenderingMode = .smartMarkdown
    
    enum TextRenderingMode: CaseIterable {
        case smartMarkdown
        case attributedString
        case webView
        
        var displayName: String {
            switch self {
            case .smartMarkdown: return "Smart Markdown"
            case .attributedString: return "Attributed String"
            case .webView: return "Web View"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch renderingMode {
            case .smartMarkdown:
                SmartMarkdownText(text: text)
            case .attributedString:
                AttributedStringText(text: text)
            case .webView:
                WebViewText(text: text)
                    .frame(minHeight: 100)
            }
        }
    }
}

// 🔹 1. SwiftUI Native Markdown (iOS 15+) - Clean & Fast
struct SmartMarkdownText: View {
    let text: String
    
    var body: some View {
        // Enhanced Markdown with better parsing
        let processedText = preprocessMarkdown(text)
        
        if let attributedString = try? AttributedString(markdown: processedText) {
            Text(attributedString)
                .textSelection(.enabled)
                .lineSpacing(2)
        } else {
            // Fallback with comprehensive manual styling
            Text(comprehensiveManualStyling(text))
                .textSelection(.enabled)
                .lineSpacing(2)
        }
    }
    
    private func preprocessMarkdown(_ input: String) -> String {
        var processed = input
        
        // Convert common patterns to proper Markdown
        processed = processed.replacingOccurrences(of: "**", with: "**") // Ensure bold works
        processed = processed.replacingOccurrences(of: "__", with: "**") // Convert underscores to asterisks
        processed = processed.replacingOccurrences(of: "_([^_]+)_", with: "*$1*", options: .regularExpression) // Single underscores to italics
        
        return processed
    }
    
    private func manuallyStyledText(_ input: String) -> AttributedString {
        var attributed = AttributedString(input)
        
        // Manual bold formatting
        let boldPattern = #"\*\*([^*]+)\*\*"#
        if let regex = try? NSRegularExpression(pattern: boldPattern) {
            let nsString = input as NSString
            let matches = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: input),
                   let contentRange = Range(match.range(at: 1), in: input) {
                    let content = String(input[contentRange])
                    let attributedRange = attributed.range(of: String(input[range]))
                    if let attributedRange = attributedRange {
                        attributed.replaceSubrange(attributedRange, with: AttributedString(content))
                        let newRange = attributed.range(of: content)
                        if let newRange = newRange {
                            attributed[newRange].font = .boldSystemFont(ofSize: 16)
                        }
                    }
                }
            }
        }
        
        return attributed
    }
    
    private func comprehensiveManualStyling(_ input: String) -> AttributedString {
        // Simplified fallback - just return the text as-is
        // The main SmartMarkdownText should handle most cases
        return AttributedString(input)
    }
    
}

// 🔹 2. NSAttributedString - Maximum Control
struct AttributedStringText: UIViewRepresentable {
    let text: String
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.attributedText = createAttributedString(from: text)
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = createAttributedString(from: text)
    }
    
    private func createAttributedString(from text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: attributed.length)
        
        // Base styling with better typography
        attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .regular), range: fullRange)
        attributed.addAttribute(.foregroundColor, value: UIColor.label, range: fullRange)
        
        // Better line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 8
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        
        // Apply formatting in order (most specific last)
        applyHeaderFormatting(to: attributed)
        applyBoldFormatting(to: attributed)
        applyItalicFormatting(to: attributed)
        applyCodeFormatting(to: attributed)
        applyLinkFormatting(to: attributed)
        applyIndentationFormatting(to: attributed)
        
        return attributed
    }
    
    private func applyHeaderFormatting(to attributed: NSMutableAttributedString) {
        // Handle different header levels
        let headerPatterns = [
            (#"^#{1}\s+(.+)$"#, UIFont.boldSystemFont(ofSize: 24)), // # H1
            (#"^#{2}\s+(.+)$"#, UIFont.boldSystemFont(ofSize: 20)), // ## H2
            (#"^#{3}\s+(.+)$"#, UIFont.boldSystemFont(ofSize: 18)), // ### H3
            (#"^#{4}\s+(.+)$"#, UIFont.boldSystemFont(ofSize: 16)), // #### H4
            (#"^#{5}\s+(.+)$"#, UIFont.boldSystemFont(ofSize: 14)), // ##### H5
            (#"^#{6}\s+(.+)$"#, UIFont.boldSystemFont(ofSize: 12))  // ###### H6
        ]
        
        let string = attributed.string
        let lines = string.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for line in lines {
            let lineLength = line.count
            let lineRange = NSRange(location: currentLocation, length: lineLength)
            
            // Check each header pattern
            for (pattern, font) in headerPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                    let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
                    
                    if let match = matches.first {
                        let contentRange = match.range(at: 1)
                        if let content = Range(contentRange, in: line) {
                            let headerText = String(line[content])
                            
                            // Replace the entire line with just the header text
                            attributed.replaceCharacters(in: lineRange, with: headerText)
                            let newRange = NSRange(location: currentLocation, length: headerText.count)
                            
                            // Apply header styling
                            attributed.addAttribute(.font, value: font, range: newRange)
                            attributed.addAttribute(.foregroundColor, value: UIColor.label, range: newRange)
                            
                            // Add extra spacing after headers
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.paragraphSpacing = 12
                            paragraphStyle.lineSpacing = 2
                            attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: newRange)
                            
                            // Update current location for the shortened text
                            currentLocation += headerText.count + 1
                            break
                        }
                    }
                }
            }
            
            // If no header pattern matched, move to next line normally
            if currentLocation < attributed.length {
                currentLocation = min(currentLocation + lineLength + 1, attributed.length)
            }
        }
    }
    
    private func applyBoldFormatting(to attributed: NSMutableAttributedString) {
        // Handle both ** and __ for bold
        let patterns = [#"\*\*([^*]+)\*\*"#, #"__([^_]+)__"#]
        
        for pattern in patterns {
            applyFormatting(to: attributed, pattern: pattern) { range in
                attributed.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: range)
                // Also make bold text slightly darker for better contrast
                attributed.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            }
        }
    }
    
    private func applyItalicFormatting(to attributed: NSMutableAttributedString) {
        // Handle both * and _ for italics (but avoid ** which is bold)
        let patterns = [
            #"(?<!\*)\*([^*]+)\*(?!\*)"#,  // *text* but not **text**
            #"(?<!_)_([^_]+)_(?!_)"#        // _text_ but not __text__
        ]
        
        for pattern in patterns {
            applyFormatting(to: attributed, pattern: pattern) { range in
                attributed.addAttribute(.font, value: UIFont.italicSystemFont(ofSize: 16), range: range)
            }
        }
    }
    
    private func applyCodeFormatting(to attributed: NSMutableAttributedString) {
        let pattern = #"`([^`]+)`"#
        applyFormatting(to: attributed, pattern: pattern) { range in
            attributed.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular), range: range)
            attributed.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: range)
            attributed.addAttribute(.foregroundColor, value: UIColor.systemPurple, range: range)
        }
    }
    
    private func applyLinkFormatting(to attributed: NSMutableAttributedString) {
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let string = attributed.string
            let matches = regex.matches(in: string, range: NSRange(location: 0, length: string.count))
            
            for match in matches.reversed() {
                let linkTextRange = match.range(at: 1)
                let linkURLRange = match.range(at: 2)
                let fullRange = match.range
                
                if let linkText = Range(linkTextRange, in: string),
                   let linkURL = Range(linkURLRange, in: string) {
                    let text = String(string[linkText])
                    let url = String(string[linkURL])
                    
                    attributed.replaceCharacters(in: fullRange, with: text)
                    let newRange = NSRange(location: fullRange.location, length: text.count)
                    
                    attributed.addAttribute(.link, value: url, range: newRange)
                    attributed.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: newRange)
                    attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: newRange)
                }
            }
        }
    }
    
    private func applyIndentationFormatting(to attributed: NSMutableAttributedString) {
        let string = attributed.string
        let lines = string.components(separatedBy: .newlines)
        var currentLocation = 0
        
        for line in lines {
            let lineLength = line.count
            let lineRange = NSRange(location: currentLocation, length: lineLength)
            
            // Handle numbered lists (1. 2. 3. etc.)
            if line.range(of: #"^\s*\d+\.\s"#, options: .regularExpression) != nil {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 20
                paragraphStyle.lineSpacing = 2
                attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
            }
            // Handle bullet lists that might not be caught by main parsing
            else if line.range(of: #"^\s*[-•*]\s"#, options: .regularExpression) != nil {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.headIndent = 20
                paragraphStyle.lineSpacing = 2
                attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
            }
            // Handle general indentation (spaces at start of line)
            else if line.hasPrefix("    ") || line.hasPrefix("\t") {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 20
                paragraphStyle.headIndent = 20
                attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: lineRange)
            }
            
            currentLocation += lineLength + 1 // +1 for newline character
        }
    }
    
    private func applyFormatting(to attributed: NSMutableAttributedString, pattern: String, formatter: (NSRange) -> Void) {
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let string = attributed.string
            let matches = regex.matches(in: string, range: NSRange(location: 0, length: string.count))
            
            for match in matches.reversed() {
                let contentRange = match.range(at: 1)
                let fullRange = match.range
                
                if let content = Range(contentRange, in: string) {
                    let text = String(string[content])
                    attributed.replaceCharacters(in: fullRange, with: text)
                    let newRange = NSRange(location: fullRange.location, length: text.count)
                    formatter(newRange)
                }
            }
        }
    }
}

// 🔹 3. WebView - Ultimate Flexibility
struct WebViewText: UIViewRepresentable {
    let text: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateStyledHTML(from: text)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func generateStyledHTML(from text: String) -> String {
        let processedText = convertMarkdownToHTML(text)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #000;
                    margin: 0;
                    padding: 12px;
                    background: transparent;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #fff; }
                }
                h1, h2, h3 { margin-top: 0.5em; margin-bottom: 0.5em; }
                p { margin: 0.5em 0; }
                strong { font-weight: 600; color: #1a1a1a; }
                @media (prefers-color-scheme: dark) {
                    strong { color: #fff; }
                }
                em { font-style: italic; color: #333; }
                @media (prefers-color-scheme: dark) {
                    em { color: #ccc; }
                }
                code {
                    background: #f5f5f5;
                    padding: 2px 4px;
                    border-radius: 3px;
                    font-family: 'SF Mono', Monaco, monospace;
                    font-size: 14px;
                    color: #d73a49;
                }
                @media (prefers-color-scheme: dark) {
                    code { background: #2d2d2d; color: #ff79c6; }
                }
                a { color: #007AFF; text-decoration: none; }
                a:hover { text-decoration: underline; }
                ul, ol { padding-left: 1.2em; margin: 0.5em 0; }
                li { margin-bottom: 0.3em; }
            </style>
        </head>
        <body>
            \(processedText)
        </body>
        </html>
        """
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // Convert bold
        html = html.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        
        // Convert italic
        html = html.replacingOccurrences(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, with: "<em>$1</em>", options: .regularExpression)
        
        // Convert inline code
        html = html.replacingOccurrences(of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression)
        
        // Convert links
        html = html.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)]+)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        
        // Convert line breaks
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = html.replacingOccurrences(of: "\n", with: "<br>")
        
        // Wrap in paragraphs
        if !html.hasPrefix("<") {
            html = "<p>" + html + "</p>"
        }
        
        return html
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            // Demo of different text formatting approaches
            Group {
                Text("🔹 1. SwiftUI Native Markdown")
                    .font(.headline)
                SmartMarkdownText(text: """
# Main Header
## Secondary Header
### Third Level Header

This is **bold text** and *italic text*.
Here's some `inline code` and a [link](https://example.com).
                
Multiple paragraphs work too!
""")
                
                Divider()
                
                Text("🔹 2. NSAttributedString")
                    .font(.headline)
                AttributedStringText(text: """
##Header Without Space
###Another Header
This is **bold text** and *italic text*.
Here's some `inline code` and a [link](https://example.com).
""")
                
                Divider()
                
                Text("🔹 3. WebView HTML/CSS")
                    .font(.headline)
                WebViewText(text: """
This is **bold text** and *italic text*.
Here's some `inline code` and a [link](https://example.com).
""")
                .frame(height: 120)
            }
            
            Divider()
            
            Text("🔹 4. Header Recognition Test")
                .font(.headline)
            
            MathFormattedText("""
## Simple Math
### What is Simple Math?

Simple math refers to basic mathematical operations and concepts that form the foundation of more complex mathematics.

### Key Terms

- **Arithmetic**: Basic operations like addition, subtraction
- **Algebra**: Mathematics dealing with variables  
- **Geometry**: Mathematics dealing with shapes

### Basic Operations
Addition: $2 + 3 = 5$
Subtraction: $5 - 2 = 3$
""")
        }
        .padding()
    }
}
