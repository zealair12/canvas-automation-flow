//
//  SearchBarView.swift
//  CanvasAutomationFlow
//
//  Created on 2025-10-01.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeManager.secondaryTextColor)
                .font(.system(size: 16))
            
            TextField(placeholder, text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundColor(themeManager.textColor)
                .futuristicFont(.futuristicBody)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeManager.secondaryTextColor)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SearchBarView(text: .constant(""))
        .environmentObject(ThemeManager())
        .padding()
        .background(Color.black)
}

