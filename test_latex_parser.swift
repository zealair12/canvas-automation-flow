#!/usr/bin/env swift

// Test script to verify LaTeX parsing
import Foundation

// Simulate the LaTeX parsing functions from MathFormattedText.swift
func parseLatexExpression(_ latex: String) -> String {
    var expression = latex
    
    // Handle fractions: \frac{numerator}{denominator}
    expression = parseFractions(expression)
    
    // Handle square roots: \sqrt{content}
    expression = parseSquareRoots(expression)
    
    // Handle superscripts and subscripts
    expression = parseSuperscripts(expression)
    expression = parseSubscripts(expression)
    
    // Handle mathematical symbols
    expression = parseMathSymbols(expression)
    
    // Clean up remaining braces and backslashes
    expression = expression.replacingOccurrences(of: "\\\\", with: "")
    
    return expression
}

func parseFractions(_ expression: String) -> String {
    var result = expression
    let fractionPattern = #"\\frac\{([^}]+)\}\{([^}]+)\}"#
    
    while let range = result.range(of: fractionPattern, options: .regularExpression) {
        let match = String(result[range])
        let numerator = extractContent(from: match, startPattern: #"\\frac\{([^}]+)\}"#)
        let denominator = extractContent(from: match, startPattern: #"\\frac\{[^}]+\}\{([^}]+)\}"#)
        
        let replacement = "(\(numerator))/(\(denominator))"
        result = result.replacingOccurrences(of: match, with: replacement)
    }
    
    return result
}

func parseSquareRoots(_ expression: String) -> String {
    var result = expression
    let sqrtPattern = #"\\sqrt\{([^}]+)\}"#
    
    while let range = result.range(of: sqrtPattern, options: .regularExpression) {
        let match = String(result[range])
        let content = extractContent(from: match, startPattern: #"\\sqrt\{([^}]+)\}"#)
        let replacement = "√(\(content))"
        result = result.replacingOccurrences(of: match, with: replacement)
    }
    
    return result
}

func parseSuperscripts(_ expression: String) -> String {
    var result = expression
    let superscriptPattern = #"\^(\d+)"#
    
    while let range = result.range(of: superscriptPattern, options: .regularExpression) {
        let match = String(result[range])
        let number = extractContent(from: match, startPattern: #"\^(\d+)"#)
        let replacement = getSuperscriptSymbol(for: number)
        result = result.replacingOccurrences(of: match, with: replacement)
    }
    
    return result
}

func parseSubscripts(_ expression: String) -> String {
    var result = expression
    let subscriptPattern = #"_(\d+)"#
    
    while let range = result.range(of: subscriptPattern, options: .regularExpression) {
        let match = String(result[range])
        let number = extractContent(from: match, startPattern: #"_(\d+)"#)
        let replacement = getSubscriptSymbol(for: number)
        result = result.replacingOccurrences(of: match, with: replacement)
    }
    
    return result
}

func parseMathSymbols(_ expression: String) -> String {
    var result = expression
    
    // Common LaTeX symbols
    let symbols = [
        "\\pm": "±",
        "\\mp": "∓",
        "\\times": "×",
        "\\div": "÷",
        "\\cdot": "·",
        "\\infty": "∞",
        "\\alpha": "α",
        "\\beta": "β",
        "\\gamma": "γ",
        "\\delta": "δ",
        "\\epsilon": "ε",
        "\\theta": "θ",
        "\\lambda": "λ",
        "\\mu": "μ",
        "\\pi": "π",
        "\\sigma": "σ",
        "\\tau": "τ",
        "\\phi": "φ",
        "\\omega": "ω",
        "\\hbar": "ℏ",
        "\\hslash": "ℏ",
        "\\ell": "ℓ",
        "\\sum": "∑",
        "\\int": "∫",
        "\\partial": "∂",
        "\\nabla": "∇",
        "\\in": "∈",
        "\\notin": "∉",
        "\\subset": "⊂",
        "\\supset": "⊃",
        "\\subseteq": "⊆",
        "\\supseteq": "⊇",
        "\\cup": "∪",
        "\\cap": "∩",
        "\\emptyset": "∅",
        "\\forall": "∀",
        "\\exists": "∃",
        "\\leq": "≤",
        "\\geq": "≥",
        "\\neq": "≠",
        "\\approx": "≈",
        "\\equiv": "≡",
        "\\propto": "∝",
        "\\rightarrow": "→",
        "\\leftarrow": "←",
        "\\leftrightarrow": "↔",
        "\\Rightarrow": "⇒",
        "\\Leftarrow": "⇐",
        "\\Leftrightarrow": "⇔"
    ]
    
    for (latex, unicode) in symbols {
        result = result.replacingOccurrences(of: latex, with: unicode)
    }
    
    return result
}

func extractContent(from text: String, startPattern: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: startPattern) else { return "" }
    let range = NSRange(location: 0, length: text.utf16.count)
    
    if let match = regex.firstMatch(in: text, options: [], range: range),
       let contentRange = Range(match.range(at: 1), in: text) {
        return String(text[contentRange])
    }
    
    return ""
}

func getSuperscriptSymbol(for number: String) -> String {
    let superscripts = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"
    ]
    return superscripts[number] ?? number
}

func getSubscriptSymbol(for number: String) -> String {
    let subscripts = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉"
    ]
    return subscripts[number] ?? number
}

// Test cases
let testCases = [
    "x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
    "ax^2 + bx + c = 0",
    "b^2 - 4ac",
    "\\sqrt{b^2 - 4ac}",
    "\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}",
    "x^2 + 5x + 6 = 0",
    "\\pm \\frac{1}{2} \\hbar",
    "\\frac{1}{2}",
    "\\hbar"
]

print("LaTeX Parser Test Results:")
print(String(repeating: "=", count: 50))

for (index, testCase) in testCases.enumerated() {
    let result = parseLatexExpression(testCase)
    print("Test \(index + 1):")
    print("Input:  \(testCase)")
    print("Output: \(result)")
    print()
}
