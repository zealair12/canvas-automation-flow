//
//  FormattedText.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-22.
//

import SwiftUI

// Helper view for formatting AI responses with asterisk emphasis
struct FormattedText: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        // Convert *text* to **text** for SwiftUI Markdown support
        let markdownText = text.replacingOccurrences(
            of: #"\*([^*]+)\*"#,
            with: "**$1**",
            options: .regularExpression
        )
        
        // Use SwiftUI's built-in Markdown support
        if let attributedString = try? AttributedString(markdown: markdownText) {
            Text(attributedString)
        } else {
            // Fallback to plain text if Markdown parsing fails
            Text(text)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FormattedText("This is *bold text* and this is normal text.")
        FormattedText("*Key concepts* include: analysis, interpretation, and *critical thinking*.")
        FormattedText("Regular text without any formatting.")
    }
    .padding()
}
