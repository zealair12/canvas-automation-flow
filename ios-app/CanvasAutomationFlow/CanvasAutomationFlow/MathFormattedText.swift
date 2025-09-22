//
//  MathFormattedText.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-22.
//

import SwiftUI
import UIKit

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
                case .header1:
                    Text(block.content)
                        .font(.title)
                        .fontWeight(.bold)
                case .header2:
                    Text(block.content)
                        .font(.title2)
                        .fontWeight(.bold)
                case .header3:
                    Text(block.content)
                        .font(.title3)
                        .fontWeight(.bold)
                case .math:
                    IosMathView(latex: block.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .text:
                    if let attributedString = try? AttributedString(markdown: block.content) {
                        Text(attributedString)
                    } else {
                        Text(block.content)
                    }
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
    case header1, header2, header3, text, math, bulletList
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

// Native iOS Math renderer using iosMath-like approach
struct IosMathView: UIViewRepresentable {
    let latex: String
    
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        
        // For now, create a styled representation of the LaTeX
        // This would be replaced with actual iosMath integration
        let styledText = formatMathForDisplay(latex)
        
        let attributedString = NSMutableAttributedString(string: styledText)
        
        // Apply math-like formatting
        attributedString.addAttribute(.font, 
                                    value: UIFont.systemFont(ofSize: 18, weight: .regular), 
                                    range: NSRange(location: 0, length: attributedString.length))
        
        // Style mathematical symbols
        styleMathSymbols(in: attributedString)
        
        label.attributedText = attributedString
        return label
    }
    
    func updateUIView(_ uiView: UILabel, context: Context) {
        // Update if needed
    }
    
    private func formatMathForDisplay(_ latex: String) -> String {
        var formatted = latex
        
        // Convert common LaTeX to readable format
        formatted = formatted.replacingOccurrences(of: "\\\\frac{", with: "(")
        formatted = formatted.replacingOccurrences(of: "}{", with: ")/(")
        formatted = formatted.replacingOccurrences(of: "\\\\sqrt{", with: "√(")
        formatted = formatted.replacingOccurrences(of: "\\\\pm", with: "±")
        formatted = formatted.replacingOccurrences(of: "^2", with: "²")
        formatted = formatted.replacingOccurrences(of: "^3", with: "³")
        formatted = formatted.replacingOccurrences(of: "_2", with: "₂")
        formatted = formatted.replacingOccurrences(of: "_3", with: "₃")
        
        // Clean up extra braces
        formatted = formatted.replacingOccurrences(of: "{{", with: "{")
        formatted = formatted.replacingOccurrences(of: "}}", with: "}")
        
        return formatted
    }
    
    private func styleMathSymbols(in attributedString: NSMutableAttributedString) {
        let string = attributedString.string
        let mathFont = UIFont.systemFont(ofSize: 20, weight: .medium)
        
        // Style mathematical symbols with larger font
        let mathSymbols = ["±", "√", "²", "³", "₂", "₃", "π", "∫", "∑", "α", "β", "γ"]
        
        for symbol in mathSymbols {
            let range = NSString(string: string).range(of: symbol)
            if range.location != NSNotFound {
                attributedString.addAttribute(.font, value: mathFont, range: range)
                attributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            }
        }
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
        
        // Check for headers
        if trimmed.hasPrefix("### ") {
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            let headerText = String(trimmed.dropFirst(4))
            blocks.append(ContentBlock(type: .header3, content: headerText))
        } else if trimmed.hasPrefix("## ") {
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            let headerText = String(trimmed.dropFirst(3))
            blocks.append(ContentBlock(type: .header2, content: headerText))
        } else if trimmed.hasPrefix("# ") {
            if !currentBulletItems.isEmpty {
                blocks.append(ContentBlock(type: .bulletList, content: "", listItems: currentBulletItems))
                currentBulletItems = []
            }
            let headerText = String(trimmed.dropFirst(2))
            blocks.append(ContentBlock(type: .header1, content: headerText))
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

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MathFormattedText("""
## Quadratic Formula

The quadratic formula is $x = \\\\frac{-b \\\\pm \\\\sqrt{b^2 - 4ac}}{2a}$

### Key concepts:
- Square root: $\\\\sqrt{x}$
- Fractions: $\\\\frac{a}{b}$
- Exponents: $x^2$

$$\\\\int_0^\\\\infty e^{-x^2} dx = \\\\frac{\\\\sqrt{\\\\pi}}{2}$$
""")
            
            Divider()
            
            MathFormattedText("""
## Water: A Fundamental Concept

Water is a **polar compound**, consisting of two hydrogen atoms and one oxygen atom ($H_2O$).

### Properties:
- Density: approximately $1 g/cm^3$
- Boiling Point: $100°C$
- Molecular angle: $104.5°$
""")
        }
        .padding()
    }
}
