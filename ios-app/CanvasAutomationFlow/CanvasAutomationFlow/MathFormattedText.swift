//
//  MathFormattedText.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-22.
//

import SwiftUI
import WebKit

// Enhanced FormattedText component with MathJax support for LaTeX rendering
struct MathFormattedText: View {
    let text: String
    @State private var renderedHeight: CGFloat = 100
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        if containsMath(text) {
            MathJaxWebView(content: text, height: $renderedHeight)
                .frame(height: renderedHeight)
        } else {
            // Use SwiftUI's native Markdown for non-math content
            if let attributedString = try? AttributedString(markdown: text) {
                Text(attributedString)
            } else {
                Text(text)
            }
        }
    }
    
    private func containsMath(_ text: String) -> Bool {
        // Check for LaTeX math delimiters
        return text.contains("$") || text.contains("\\(") || text.contains("\\[")
    }
}

// WebKit-based MathJax renderer
struct MathJaxWebView: UIViewRepresentable {
    let content: String
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let htmlContent = generateMathJaxHTML(content: content)
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MathJaxWebView
        
        init(_ parent: MathJaxWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Auto-resize based on content
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.height = max(height + 20, 50) // Add padding
                    }
                }
            }
        }
    }
    
    private func generateMathJaxHTML(content: String) -> String {
        // Convert Markdown to HTML while preserving LaTeX
        let htmlContent = convertMarkdownToHTML(content)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <script>
                window.MathJax = {
                    tex: {
                        inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                        displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                        processEscapes: true,
                        processEnvironments: true
                    },
                    options: {
                        skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre']
                    }
                };
            </script>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: 16px;
                    line-height: 1.5;
                    margin: 10px;
                    padding: 0;
                    background: transparent;
                    color: #000;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #fff; }
                }
                h1, h2, h3 { margin-top: 1em; margin-bottom: 0.5em; }
                ul, ol { padding-left: 1.5em; }
                li { margin-bottom: 0.25em; }
                strong { font-weight: 600; }
                .MathJax { font-size: 1.1em !important; }
            </style>
        </head>
        <body>
            \(htmlContent)
        </body>
        </html>
        """
    }
    
    private func convertMarkdownToHTML(_ markdown: String) -> String {
        var html = markdown
        
        // Convert headers
        html = html.replacingOccurrences(of: #"^### (.+)$"#, with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^## (.+)$"#, with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^# (.+)$"#, with: "<h1>$1</h1>", options: .regularExpression)
        
        // Convert bold and italic (preserve LaTeX)
        html = html.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"(?<!\*)\*([^*]+)\*(?!\*)"#, with: "<em>$1</em>", options: .regularExpression)
        
        // Convert lists
        let lines = html.components(separatedBy: .newlines)
        var result: [String] = []
        var inList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                if !inList {
                    result.append("<ul>")
                    inList = true
                }
                let content = String(trimmed.dropFirst(2))
                result.append("<li>\(content)</li>")
            } else {
                if inList {
                    result.append("</ul>")
                    inList = false
                }
                result.append(line)
            }
        }
        
        if inList {
            result.append("</ul>")
        }
        
        // Convert newlines to <br> for paragraphs
        html = result.joined(separator: "\n").replacingOccurrences(of: "\n\n", with: "<br><br>")
        
        return html
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MathFormattedText("## Quadratic Formula\n\nThe quadratic formula is $x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$")
            
            MathFormattedText("**Key concepts:**\n- Square root: $\\sqrt{x}$\n- Fractions: $\\frac{a}{b}$\n- Exponents: $x^2$")
            
            MathFormattedText("$$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$")
        }
        .padding()
    }
}
