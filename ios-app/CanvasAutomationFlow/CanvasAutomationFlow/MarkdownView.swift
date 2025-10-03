//
//  MarkdownView.swift
//  CanvasAutomationFlow
//
//  ChatGPT-like Markdown Renderer with LaTeX and Citation Support
//

import SwiftUI
import WebKit

struct MarkdownView: View {
    let content: String
    let sources: [Citation]?
    @State private var webViewHeight: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownWebView(
                content: content,
                sources: sources,
                height: $webViewHeight
            )
            .frame(height: webViewHeight)
        }
    }
}

struct Citation: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let snippet: String?
    
    init(id: String, title: String, url: String, snippet: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

struct MarkdownWebView: UIViewRepresentable {
    let content: String
    let sources: [Citation]?
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure WKWebView with JavaScript enabled for MathJax
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(content: content, sources: sources)
        webView.loadHTMLString(html, baseURL: nil)
        
        // Calculate height after content loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                if let height = result as? CGFloat {
                    self.height = height
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MarkdownWebView
        
        init(_ parent: MarkdownWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // Handle external links
                if url.scheme == "http" || url.scheme == "https" {
                    UIApplication.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
                // Handle citation links
                else if url.scheme == "citation" {
                    // Open citation detail
                    print("Citation clicked: \(url.absoluteString)")
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
    
    func generateHTML(content: String, sources: [Citation]?) -> String {
        // Process markdown and LaTeX
        let processedContent = processMarkdown(content)
        
        // Generate citations section
        var citationsHTML = ""
        if let sources = sources, !sources.isEmpty {
            citationsHTML = """
            <div class="citations-section">
                <h3>Sources</h3>
                <div class="citations-list">
            """
            
            for (index, source) in sources.enumerated() {
                citationsHTML += """
                <div class="citation-item" id="citation-\(index + 1)">
                    <div class="citation-number">[\(index + 1)]</div>
                    <div class="citation-content">
                        <a href="\(source.url)" class="citation-title">\(source.title)</a>
                        \(source.snippet != nil ? "<p class='citation-snippet'>\(source.snippet!)</p>" : "")
                    </div>
                </div>
                """
            }
            
            citationsHTML += """
                </div>
            </div>
            """
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <script>
                MathJax = {
                    tex: {
                        inlineMath: [['$', '$']],
                        displayMath: [['$$', '$$']],
                        processEscapes: true
                    },
                    svg: {
                        fontCache: 'global'
                    }
                };
            </script>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: #1a1a1a;
                    padding: 16px;
                    background: transparent;
                }
                
                /* Headers */
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 24px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.25;
                }
                
                h1 { font-size: 2em; border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3em; }
                h2 { font-size: 1.5em; border-bottom: 1px solid #e1e4e8; padding-bottom: 0.3em; }
                h3 { font-size: 1.25em; }
                h4 { font-size: 1em; }
                
                /* Paragraphs */
                p {
                    margin-bottom: 16px;
                }
                
                /* Lists */
                ul, ol {
                    margin-bottom: 16px;
                    padding-left: 2em;
                }
                
                li {
                    margin-bottom: 8px;
                }
                
                /* Code */
                code {
                    background-color: rgba(175, 184, 193, 0.2);
                    padding: 0.2em 0.4em;
                    border-radius: 6px;
                    font-family: 'SF Mono', 'Monaco', 'Courier New', monospace;
                    font-size: 0.875em;
                }
                
                pre {
                    background-color: #f6f8fa;
                    border-radius: 6px;
                    padding: 16px;
                    overflow-x: auto;
                    margin-bottom: 16px;
                }
                
                pre code {
                    background-color: transparent;
                    padding: 0;
                }
                
                /* Links */
                a {
                    color: #0969da;
                    text-decoration: none;
                }
                
                a:hover {
                    text-decoration: underline;
                }
                
                /* Bold and Italic */
                strong {
                    font-weight: 600;
                }
                
                em {
                    font-style: italic;
                }
                
                /* Blockquotes */
                blockquote {
                    border-left: 4px solid #d0d7de;
                    padding-left: 16px;
                    margin-left: 0;
                    margin-bottom: 16px;
                    color: #57606a;
                }
                
                /* Tables */
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin-bottom: 16px;
                }
                
                table th,
                table td {
                    padding: 8px 13px;
                    border: 1px solid #d0d7de;
                }
                
                table th {
                    background-color: #f6f8fa;
                    font-weight: 600;
                }
                
                table tr:nth-child(even) {
                    background-color: #f6f8fa;
                }
                
                /* Citations */
                .citation-ref {
                    display: inline-block;
                    background-color: #0969da;
                    color: white;
                    padding: 0 6px;
                    border-radius: 4px;
                    font-size: 0.875em;
                    margin: 0 2px;
                    text-decoration: none;
                    font-weight: 500;
                }
                
                .citation-ref:hover {
                    background-color: #0550ae;
                }
                
                .citations-section {
                    margin-top: 32px;
                    padding-top: 24px;
                    border-top: 2px solid #d0d7de;
                }
                
                .citations-section h3 {
                    font-size: 1.25em;
                    margin-bottom: 16px;
                }
                
                .citations-list {
                    display: flex;
                    flex-direction: column;
                    gap: 12px;
                }
                
                .citation-item {
                    display: flex;
                    gap: 12px;
                    padding: 12px;
                    background-color: #f6f8fa;
                    border-radius: 6px;
                    border-left: 3px solid #0969da;
                }
                
                .citation-number {
                    flex-shrink: 0;
                    font-weight: 600;
                    color: #0969da;
                }
                
                .citation-content {
                    flex: 1;
                }
                
                .citation-title {
                    font-weight: 500;
                    color: #0969da;
                    display: block;
                    margin-bottom: 4px;
                }
                
                .citation-snippet {
                    font-size: 0.875em;
                    color: #57606a;
                    margin-top: 4px;
                }
                
                /* Math */
                .MathJax {
                    font-size: 1.1em !important;
                }
                
                /* Horizontal rule */
                hr {
                    height: 0.25em;
                    padding: 0;
                    margin: 24px 0;
                    background-color: #d0d7de;
                    border: 0;
                }
                
                /* Dark mode support */
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #e6edf3;
                    }
                    
                    h1, h2 {
                        border-bottom-color: #30363d;
                    }
                    
                    code {
                        background-color: rgba(110, 118, 129, 0.4);
                    }
                    
                    pre {
                        background-color: #161b22;
                    }
                    
                    blockquote {
                        border-left-color: #3b434b;
                        color: #8b949e;
                    }
                    
                    table th,
                    table td {
                        border-color: #30363d;
                    }
                    
                    table th {
                        background-color: #161b22;
                    }
                    
                    table tr:nth-child(even) {
                        background-color: #0d1117;
                    }
                    
                    .citations-section {
                        border-top-color: #30363d;
                    }
                    
                    .citation-item {
                        background-color: #161b22;
                        border-left-color: #58a6ff;
                    }
                    
                    .citation-number {
                        color: #58a6ff;
                    }
                    
                    .citation-title {
                        color: #58a6ff;
                    }
                    
                    .citation-snippet {
                        color: #8b949e;
                    }
                    
                    a {
                        color: #58a6ff;
                    }
                    
                    hr {
                        background-color: #30363d;
                    }
                }
            </style>
        </head>
        <body>
            \(processedContent)
            \(citationsHTML)
        </body>
        </html>
        """
    }
    
    func processMarkdown(_ markdown: String) -> String {
        var html = markdown
        
        // Process inline citations [1], [2], etc.
        let citationPattern = "\\[(\\d+)\\]"
        if let regex = try? NSRegularExpression(pattern: citationPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: html) {
                    let number = String(html[range]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    let replacement = "<a href='#citation-\(number)' class='citation-ref'>[\(number)]</a>"
                    html.replaceSubrange(range, with: replacement)
                }
            }
        }
        
        // Convert headers
        html = html.replacingOccurrences(of: "### ", with: "<h3>")
        html = html.replacingOccurrences(of: "## ", with: "<h2>")
        html = html.replacingOccurrences(of: "# ", with: "<h1>")
        html = html.replacingOccurrences(of: "\n", with: "</h3>\n", options: [], range: html.range(of: "<h3>"))
        html = html.replacingOccurrences(of: "\n", with: "</h2>\n", options: [], range: html.range(of: "<h2>"))
        html = html.replacingOccurrences(of: "\n", with: "</h1>\n", options: [], range: html.range(of: "<h1>"))
        
        // Convert bold **text**
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        
        // Convert italic *text*
        html = html.replacingOccurrences(of: "\\*(.+?)\\*", with: "<em>$1</em>", options: .regularExpression)
        
        // Convert inline code `code`
        html = html.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Convert lists
        let lines = html.components(separatedBy: "\n")
        var processedLines: [String] = []
        var inList = false
        
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                if !inList {
                    processedLines.append("<ul>")
                    inList = true
                }
                let item = line.replacingOccurrences(of: "^- ", with: "", options: .regularExpression)
                processedLines.append("<li>\(item)</li>")
            } else {
                if inList {
                    processedLines.append("</ul>")
                    inList = false
                }
                processedLines.append(line)
            }
        }
        
        if inList {
            processedLines.append("</ul>")
        }
        
        html = processedLines.joined(separator: "\n")
        
        // Convert paragraphs
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        
        // Clean up empty paragraphs
        html = html.replacingOccurrences(of: "<p></p>", with: "")
        html = html.replacingOccurrences(of: "<p> </p>", with: "")
        
        return html
    }
}

// Preview
struct MarkdownView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MarkdownView(
                content: """
                # Sample Assignment
                
                This is a **bold** statement and this is *italic*.
                
                ## Introduction
                
                Here's some inline math: $E = mc^2$
                
                And display math:
                
                $$\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}$$
                
                ## Key Points
                
                - First point [1]
                - Second point with citation [2]
                - Third point
                
                This research shows important findings [1][2].
                
                ## Code Example
                
                Here's some `inline code` and a code block:
                
                ```python
                def hello_world():
                    print("Hello, World!")
                ```
                """,
                sources: [
                    Citation(id: "1", title: "Research Paper 1", url: "https://example.com/paper1", snippet: "Important findings about the topic..."),
                    Citation(id: "2", title: "Research Paper 2", url: "https://example.com/paper2", snippet: "Additional context and evidence...")
                ]
            )
            .padding()
        }
    }
}

