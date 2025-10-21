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
    let backgroundColor: Color
    @State private var webViewHeight: CGFloat = 0
    
    init(content: String, sources: [Citation]? = nil, backgroundColor: Color = Color(.systemGray6)) {
        self.content = content
        self.sources = sources
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownWebView(
                content: content,
                sources: sources,
                backgroundColor: backgroundColor,
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
    let backgroundColor: Color
    @Binding var height: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        // Configure WKWebView with JavaScript enabled for MathJax
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(backgroundColor)
        webView.scrollView.backgroundColor = UIColor(backgroundColor)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(content: content, sources: sources)
        webView.loadHTMLString(html, baseURL: nil)
        
        // DEBUG: Enhanced debugging checks
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webView.evaluateJavaScript("document.getElementById('content').innerHTML") { result, error in
                print("🔍 WEBVIEW innerHTML:", result ?? "nil", "err:", error ?? "nil")
            }
            webView.evaluateJavaScript("document.getElementById('content').innerText") { result, error in
                print("🔍 WEBVIEW innerText:", result ?? "nil", "err:", error ?? "nil")
            }
            webView.evaluateJavaScript("window.MathJax !== undefined") { result, _ in
                print("🔍 MathJax defined?", result ?? "nil")
            }
        }
        
        // Calculate height after content loads and MathJax processes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // Force MathJax to reprocess all math expressions
            webView.evaluateJavaScript("""
                if (typeof MathJax !== 'undefined' && MathJax.typesetPromise) {
                    MathJax.typesetPromise().then(function() {
                        console.log('MathJax processing completed');
                        return document.body.scrollHeight;
                    }).then(function(height) {
                        window.webkit.messageHandlers.heightHandler.postMessage(height);
                    });
                } else {
                    console.log('MathJax not ready, retrying...');
                    setTimeout(function() {
                        if (typeof MathJax !== 'undefined' && MathJax.typesetPromise) {
                            MathJax.typesetPromise().then(function() {
                                return document.body.scrollHeight;
                            }).then(function(height) {
                                window.webkit.messageHandlers.heightHandler.postMessage(height);
                            });
                        }
                    }, 500);
                }
            """) { _, _ in
                // Fallback height calculation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    webView.evaluateJavaScript("document.body.scrollHeight") { result, error in
                        if let height = result as? CGFloat {
                            self.height = height
                        }
                    }
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
        // DEBUG: Print raw markdown before any processing
        print("🔍 DEBUG - RAW markdown before protect:", content)
        
        // Use robust HTML generation
        return generateMathHTMLRobust(from: content, sources: sources)
    }
    
    func backgroundColorToHex(_ color: Color) -> String {
        // Convert Color to hex string for HTML
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)
        
        return String(format: "#%02x%02x%02x", r, g, b)
    }
    
    func isDarkBackground(_ color: Color) -> Bool {
        // Determine if the background color is dark
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate luminance
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }
    
    func generateMathHTMLRobust(from markdown: String, sources: [Citation]?) -> String {
        // 1) Protect LaTeX (same tokens you used)
        let protected = protectLaTeXExpressions(markdown)
        print("🔍 DEBUG - After protection:", protected)
        
        // 2) Convert markdown -> html (use existing processMarkdown but skip LaTeX steps)
        let htmlBody = processMarkdownWithoutLaTeX(protected, sources: sources)
        print("🔍 DEBUG - After markdown conversion:", htmlBody)
        
        // 3) Restore tokens back to LaTeX delimiters
        let restoredHTML = restoreLaTeXExpressions(htmlBody)
        print("🔍 DEBUG - After restoration:", restoredHTML)
        
        // 4) Get background color hex and determine text color
        let bgHex = backgroundColorToHex(backgroundColor)
        let textColor = isDarkBackground(backgroundColor) ? "#ffffff" : "#000000"
        
        // 4) Generate citations section
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
        
        // 5) Full HTML document with dynamic script load + robust logging
        let fullHTML = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: \(textColor); background: \(bgHex); padding: 8px 12px; margin: 0; }
            code { background: rgba(255,255,255,0.1); padding:2px 4px; border-radius:4px; }
            h1, h2, h3, h4, h5, h6 { color: \(textColor); margin-top: 1em; margin-bottom: 0.5em; }
            p { color: \(textColor); margin-bottom: 1em; }
            ul, ol { color: \(textColor); }
            li { color: \(textColor); margin-bottom: 0.25em; }
            strong { color: \(textColor); font-weight: 600; }
            em { color: \(textColor); font-style: italic; }
            table { border-collapse: collapse; width: 100%; margin: 1em 0; }
            th, td { border: 1px solid rgba(255,255,255,0.2); padding: 8px; text-align: left; color: \(textColor); }
            th { background-color: rgba(255,255,255,0.1); font-weight: 600; }
            tr:nth-child(even) { background-color: rgba(255,255,255,0.05); }
            hr { border: none; border-top: 1px solid rgba(255,255,255,0.2); margin: 1em 0; }
            .citations-section { margin-top: 32px; padding-top: 24px; border-top: 2px solid #d0d7de; }
            .citations-section h3 { font-size: 1.25em; margin-bottom: 16px; color: \(textColor); }
            .citations-list { display: flex; flex-direction: column; gap: 12px; }
            .citation-item { display: flex; gap: 12px; padding: 12px; background-color: #f6f8fa; border-radius: 6px; border-left: 3px solid #0969da; }
            .citation-number { flex-shrink: 0; font-weight: 600; color: #0969da; }
            .citation-content { flex: 1; }
            .citation-title { font-weight: 500; color: #0969da; display: block; margin-bottom: 4px; }
            .citation-snippet { font-size: 0.875em; color: #57606a; margin-top: 4px; }
            .citation-ref { display: inline-block; background-color: #0969da; color: white; padding: 0 6px; border-radius: 4px; font-size: 0.875em; margin: 0 2px; text-decoration: none; font-weight: 500; }
          </style>
        </head>
        <body>
          <div id="content">
            \(restoredHTML)
            \(citationsHTML)
          </div>

          <script>
            console.log("STAGE: Loaded HTML into DOM");

            function debugDump() {
              try {
                console.log("DEBUG innerHTML:", document.getElementById('content').innerHTML);
                console.log("DEBUG innerText:", document.getElementById('content').innerText);
              } catch(e) { console.error("DEBUG dump error", e); }
            }
            debugDump();

            // Add MathJax script dynamically and wait for it to load
            window.MathJax = {
              tex: {
                inlineMath: [['$', '$'], ['\\\\(', '\\\\)']],
                displayMath: [['$$', '$$'], ['\\\\[', '\\\\]']],
                processEscapes: true,
                processEnvironments: true
              },
              options: {
                skipHtmlTags: ['script','noscript','style','textarea','pre'], // do NOT include 'code'
                ignoreHtmlClass: 'tex2jax_ignore',
                processHtmlClass: 'tex2jax_process'
              }
            };

            (function() {
              var script = document.createElement('script');
              script.src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js";
              script.async = true;
              script.onload = function() {
                console.log("MathJax script loaded (onload)");
                if (window.MathJax && MathJax.typesetPromise) {
                  MathJax.typesetPromise().then(function() {
                    console.log("✅ MathJax typesetPromise completed");
                    debugDump();
                  }).catch(function(err){
                    console.error("❌ MathJax typesetPromise failed:", err);
                    debugDump();
                  });
                } else {
                  console.error("MathJax not ready after load");
                  debugDump();
                }
              };
              script.onerror = function(e) {
                console.error("Failed to load MathJax script", e);
              };
              document.head.appendChild(script);
            }());
          </script>
        </body>
        </html>
        """
        return fullHTML
    }
    
    func processMarkdownWithoutLaTeX(_ markdown: String, sources: [Citation]?) -> String {
        var html = markdown
        
        // Process inline citations [1], [2], etc.
        let citationPattern = "\\[(\\d+)\\]"
        if let regex = try? NSRegularExpression(pattern: citationPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: html) {
                    let number = String(html[range]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    
                    // Find the corresponding source URL
                    var citationURL = "#citation-\(number)" // Default to internal anchor
                    if let sources = sources, let citationNumber = Int(number), citationNumber <= sources.count {
                        let source = sources[citationNumber - 1] // Convert to 0-based index
                        citationURL = source.url
                    }
                    
                    let replacement = "<a href='\(citationURL)' class='citation-ref'>[\(number)]</a>"
                    html.replaceSubrange(range, with: replacement)
                }
            }
        }
        
        // Process tables first (before other conversions)
        html = processTables(html)
        
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
        
        // Convert inline code `code` (but skip LaTeX expressions)
        html = html.replacingOccurrences(of: "`(?!\\\\\\()[^`]+?`", with: "<code>$1</code>", options: .regularExpression)
        
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
        
        // Convert horizontal rules (---)
        html = html.replacingOccurrences(of: "\n---\n", with: "\n<hr>\n")
        html = html.replacingOccurrences(of: "\n---", with: "\n<hr>")
        html = html.replacingOccurrences(of: "---\n", with: "<hr>\n")
        
        // Convert paragraphs
        html = html.replacingOccurrences(of: "\n\n", with: "</p><p>")
        html = "<p>" + html + "</p>"
        
        // Clean up empty paragraphs
        html = html.replacingOccurrences(of: "<p></p>", with: "")
        html = html.replacingOccurrences(of: "<p> </p>", with: "")
        
        return html
    }
    
    func generateHTML_OLD(content: String, sources: [Citation]?) -> String {
        // Process markdown and LaTeX
        let processedContent = processMarkdown(content, sources: sources)
        
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
                        inlineMath: [['$', '$'], ['\\(', '\\)']],
                        displayMath: [['$$', '$$'], ['\\[', '\\]']],
                        processEscapes: true,
                        processEnvironments: true,
                        processRefs: true
                    },
                    svg: {
                        fontCache: 'global'
                    },
                    startup: {
                        ready: function () {
                            MathJax.startup.defaultReady();
                            console.log('MathJax is ready');
                            // Force initial typesetting
                            MathJax.typesetPromise();
                        }
                    },
                    options: {
                        skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre'],
                        ignoreHtmlClass: 'tex2jax_ignore',
                        processHtmlClass: 'tex2jax_process'
                    }
                };
                
                // Additional processing function
                function processMath() {
                    if (typeof MathJax !== 'undefined' && MathJax.typesetPromise) {
                        MathJax.typesetPromise().then(function() {
                            console.log('Math processing completed');
                        }).catch(function(err) {
                            console.log('Math processing error:', err);
                        });
                    }
                }
                
                // Process math when page loads
                document.addEventListener('DOMContentLoaded', function() {
                    MathJax.typesetPromise().then(function() {
                        console.log('✅ MathJax processing completed');
                    }).catch(function(err) {
                        console.error('❌ MathJax processing failed:', err);
                    });
                });
            </script>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', 'Times New Roman', serif;
                    font-size: 16px;
                    line-height: 1.7;
                    color: #1a1a1a;
                    padding: 20px;
                    background: transparent;
                    max-width: 800px;
                    margin: 0 auto;
                }
                
                /* Headers - Academic Style */
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 32px;
                    margin-bottom: 16px;
                    font-weight: 600;
                    line-height: 1.3;
                    color: #2c3e50;
                }
                
                h1 { 
                    font-size: 2.2em; 
                    border-bottom: 2px solid #e1e4e8; 
                    padding-bottom: 0.4em; 
                    margin-top: 0;
                }
                h2 { 
                    font-size: 1.6em; 
                    border-bottom: 1px solid #e1e4e8; 
                    padding-bottom: 0.3em; 
                }
                h3 { 
                    font-size: 1.3em; 
                    color: #34495e;
                }
                h4 { 
                    font-size: 1.1em; 
                    color: #34495e;
                }
                
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
                
                /* Tables - Overleaf/PDF Style */
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 20px 0;
                    font-size: 0.9em;
                    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
                    border-radius: 8px;
                    overflow: hidden;
                }
                
                table th,
                table td {
                    padding: 12px 16px;
                    border: 1px solid #d0d7de;
                    text-align: left;
                    vertical-align: top;
                }
                
                table th {
                    background-color: #f6f8fa;
                    font-weight: 600;
                    color: #24292f;
                    border-bottom: 2px solid #d0d7de;
                }
                
                table tr:nth-child(even) {
                    background-color: #f8f9fa;
                }
                
                table tr:hover {
                    background-color: #f1f3f4;
                }
                
                table td:first-child,
                table th:first-child {
                    border-left: none;
                }
                
                table td:last-child,
                table th:last-child {
                    border-right: none;
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
                    
                    h1, h2, h3, h4, h5, h6 {
                        color: #e6edf3;
                    }
                    
                    h1, h2 {
                        border-bottom-color: #30363d;
                    }
                    
                    h3, h4 {
                        color: #c9d1d9;
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
                    
                    table {
                        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
                    }
                    
                    table th,
                    table td {
                        border-color: #30363d;
                    }
                    
                    table th {
                        background-color: #161b22;
                        color: #f0f6fc;
                        border-bottom-color: #30363d;
                    }
                    
                    table tr:nth-child(even) {
                        background-color: #0d1117;
                    }
                    
                    table tr:hover {
                        background-color: #21262d;
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
    
    func processMarkdown(_ markdown: String, sources: [Citation]?) -> String {
        var html = markdown
        
        // DEBUG: Print original input
        print("🔍 DEBUG - Original markdown:", html)
        
        // STEP 1: Protect ALL LaTeX expressions first (before any other processing)
        html = protectLaTeXExpressions(html)
        
        // DEBUG: Print after protection
        print("🔍 DEBUG - After LaTeX protection:", html)
        
        // Process inline citations [1], [2], etc.
        let citationPattern = "\\[(\\d+)\\]"
        if let regex = try? NSRegularExpression(pattern: citationPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, options: [], range: range)
            
            for match in matches.reversed() {
                if let range = Range(match.range, in: html) {
                    let number = String(html[range]).replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    
                    // Find the corresponding source URL
                    var citationURL = "#citation-\(number)" // Default to internal anchor
                    if let sources = sources, let citationNumber = Int(number), citationNumber <= sources.count {
                        let source = sources[citationNumber - 1] // Convert to 0-based index
                        citationURL = source.url
                    }
                    
                    let replacement = "<a href='\(citationURL)' class='citation-ref'>[\(number)]</a>"
                    html.replaceSubrange(range, with: replacement)
                }
            }
        }
        
        // Process tables first (before other conversions)
        html = processTables(html)
        
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
        
        // Convert inline code `code` (but skip LaTeX expressions)
        html = html.replacingOccurrences(of: "`(?!\\\\\\()[^`]+?`", with: "<code>$1</code>", options: .regularExpression)
        
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
        
        // STEP FINAL: Restore LaTeX expressions
        html = restoreLaTeXExpressions(html)
        
        // DEBUG: Print final result
        print("🔍 DEBUG - Final HTML after restoration:", html)
        
        return html
    }
    
    // MARK: - LaTeX Protection Functions
    
    func protectLaTeXExpressions(_ text: String) -> String {
        var result = text
        
        // Protect display math: \[ ... \]
        result = result.replacingOccurrences(
            of: #"\\\[(.*?)\\\]"#,
            with: "⟦LATEX_DISPLAY_START⟧$1⟦LATEX_DISPLAY_END⟧",
            options: .regularExpression
        )
        
        // Protect inline math: \( ... \)
        result = result.replacingOccurrences(
            of: #"\\\((.*?)\\\)"#,
            with: "⟦LATEX_INLINE_START⟧$1⟦LATEX_INLINE_END⟧",
            options: .regularExpression
        )
        
        // Protect dollar math: $$ ... $$ (display)
        result = result.replacingOccurrences(
            of: #"\$\$(.*?)\$\$"#,
            with: "⟦LATEX_DISPLAY_START⟧$1⟦LATEX_DISPLAY_END⟧",
            options: .regularExpression
        )
        
        // Protect dollar math: $ ... $ (inline)
        result = result.replacingOccurrences(
            of: #"\$(.*?)\$"#,
            with: "⟦LATEX_INLINE_START⟧$1⟦LATEX_INLINE_END⟧",
            options: .regularExpression
        )
        
        return result
    }
    
    func restoreLaTeXExpressions(_ html: String) -> String {
        var result = html
        
        // Restore display math (prioritize \[ ... \] over $$ ... $$)
        result = result.replacingOccurrences(of: "⟦LATEX_DISPLAY_START⟧", with: "\\[")
        result = result.replacingOccurrences(of: "⟦LATEX_DISPLAY_END⟧", with: "\\]")
        
        // Restore inline math (prioritize \( ... \) over $ ... $)
        result = result.replacingOccurrences(of: "⟦LATEX_INLINE_START⟧", with: "\\(")
        result = result.replacingOccurrences(of: "⟦LATEX_INLINE_END⟧", with: "\\)")
        
        return result
    }
    
    func processTables(_ html: String) -> String {
        let lines = html.components(separatedBy: "\n")
        var processedLines: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check if this line looks like a table header (contains |)
            if line.contains("|") && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                var tableLines: [String] = []
                var j = i
                
                // Collect all table lines
                while j < lines.count && lines[j].contains("|") && !lines[j].trimmingCharacters(in: .whitespaces).isEmpty {
                    tableLines.append(lines[j])
                    j += 1
                }
                
                // Check if we have at least 2 lines (header + separator)
                if tableLines.count >= 2 {
                    let tableHTML = convertTableToHTML(tableLines)
                    processedLines.append(tableHTML)
                    i = j - 1 // Skip processed lines
                } else {
                    processedLines.append(line)
                }
            } else {
                processedLines.append(line)
            }
            
            i += 1
        }
        
        return processedLines.joined(separator: "\n")
    }
    
    func convertTableToHTML(_ tableLines: [String]) -> String {
        var html = "<table>\n"
        
        for (index, line) in tableLines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip separator lines (contain only |, -, spaces)
            if trimmedLine.matches("^\\s*\\|?\\s*:?-+:?\\s*(\\|\\s*:?-+:?\\s*)*\\|?\\s*$") {
                continue
            }
            
            let cells = trimmedLine.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            if !cells.isEmpty {
                let tag = index == 0 ? "th" : "td"
                html += "  <tr>\n"
                
                for cell in cells {
                    html += "    <\(tag)>\(cell)</\(tag)>\n"
                }
                
                html += "  </tr>\n"
            }
        }
        
        html += "</table>"
        return html
    }
}

// String extension for regex matching
extension String {
    func matches(_ pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(self.startIndex..., in: self)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
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
                
                Here's some inline math: $E = mc^2$ and \\(H_2O\\)
                
                And display math:
                
                $$\\int_{-\\infty}^{\\infty} e^{-x^2} dx = \\sqrt{\\pi}$$
                
                Also with parentheses: \\[\\sum_{i=1}^{n} x_i = x_1 + x_2 + \\cdots + x_n\\]
                
                ## Key Points
                
                - First point [1]
                - Second point with citation [2]
                - Third point
                
                This research shows important findings [1][2].
                
                ## Comparison Table
                
                | Group          | Characteristics                          | Examples                |
                |----------------|----------------------------------------|-------------------------|
                | Strepsirrhines | Wet noses, nocturnal, smaller brains   | Lemurs, lorises         |
                | Haplorhines    | Dry noses, diurnal, larger brains      | Monkeys, apes, humans   |
                
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

