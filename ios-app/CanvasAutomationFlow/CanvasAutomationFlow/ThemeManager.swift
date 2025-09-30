//
//  ThemeManager.swift
//  CanvasAutomationFlow
//
//  Created on 2025-09-29.
//

import SwiftUI

// MARK: - Dark Theme Colors
extension Color {
    static let darkBackground = Color(red: 0.07, green: 0.07, blue: 0.07) // #121212
    static let darkSurface = Color(red: 0.12, green: 0.12, blue: 0.12)   // #1F1F1F
    static let darkAccent = Color(red: 0.73, green: 0.53, blue: 0.99)    // #BB86FC
    static let darkSecondary = Color(red: 0.03, green: 0.21, blue: 0.14) // #03DAC6
    static let darkText = Color(red: 0.95, green: 0.95, blue: 0.95)      // #F2F2F2
    static let darkTextSecondary = Color(red: 0.7, green: 0.7, blue: 0.7) // #B3B3B3
    static let darkError = Color(red: 0.96, green: 0.26, blue: 0.21)     // #F44336
    static let darkSuccess = Color(red: 0.3, green: 0.69, blue: 0.31)    // #4CAF50
    static let darkWarning = Color(red: 1.0, green: 0.76, blue: 0.03)    // #FF9800
}

// MARK: - Custom Fonts
extension Font {
    static let futuristicTitle = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let futuristicHeadline = Font.system(size: 18, weight: .semibold, design: .monospaced)
    static let futuristicBody = Font.system(size: 16, weight: .regular, design: .monospaced)
    static let futuristicCaption = Font.system(size: 14, weight: .light, design: .monospaced)
    static let futuristicCode = Font.system(size: 14, weight: .medium, design: .monospaced)
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    @Published var isDarkMode: Bool = true
    @Published var useFuturisticFont: Bool = true
    
    init() {
        // Default to dark mode
        self.isDarkMode = true
        self.useFuturisticFont = true
    }
    
    var backgroundColor: Color {
        isDarkMode ? .darkBackground : .white
    }
    
    var surfaceColor: Color {
        isDarkMode ? .darkSurface : Color(.systemGray6)
    }
    
    var accentColor: Color {
        isDarkMode ? .darkAccent : .blue
    }
    
    var textColor: Color {
        isDarkMode ? .darkText : .primary
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? .darkTextSecondary : .secondary
    }
}

// MARK: - Custom View Modifiers
struct DarkThemeModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .background(themeManager.backgroundColor)
            .foregroundColor(themeManager.textColor)
    }
}

struct FuturisticCardModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .background(themeManager.surfaceColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: themeManager.accentColor.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

struct GlowingBorderModifier: ViewModifier {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isGlowing = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                themeManager.accentColor.opacity(isGlowing ? 0.8 : 0.3),
                                themeManager.accentColor.opacity(isGlowing ? 0.4 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isGlowing.toggle()
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func darkTheme() -> some View {
        self.modifier(DarkThemeModifier())
    }
    
    func futuristicCard() -> some View {
        self.modifier(FuturisticCardModifier())
    }
    
    func glowingBorder() -> some View {
        self.modifier(GlowingBorderModifier())
    }
    
    func futuristicFont(_ style: Font = .futuristicBody) -> some View {
        self.font(style)
    }
}

// MARK: - Custom Components
struct FuturisticButton: View {
    let title: String
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [themeManager.accentColor, themeManager.accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(8)
                .shadow(color: themeManager.accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

struct FuturisticTextField: View {
    let title: String
    @Binding var text: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .futuristicFont(.futuristicCaption)
                .foregroundColor(themeManager.secondaryTextColor)
            
            TextField("", text: $text)
                .futuristicFont(.futuristicBody)
                .padding(12)
                .background(themeManager.surfaceColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

struct CommandConsole: View {
    @State private var command = ""
    @State private var responses: [String] = []
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Console")
                .futuristicFont(.futuristicHeadline)
                .foregroundColor(themeManager.accentColor)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(responses, id: \.self) { response in
                        Text(response)
                            .futuristicFont(.futuristicCode)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(8)
                            .background(themeManager.surfaceColor)
                            .cornerRadius(6)
                    }
                }
            }
            .frame(height: 200)
            
            HStack {
                Text(">")
                    .futuristicFont(.futuristicCode)
                    .foregroundColor(themeManager.accentColor)
                
                TextField("Enter command...", text: $command)
                    .futuristicFont(.futuristicCode)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onSubmit {
                        executeCommand()
                    }
            }
            .padding(8)
            .background(themeManager.surfaceColor)
            .cornerRadius(6)
        }
        .padding()
        .futuristicCard()
    }
    
    private func executeCommand() {
        let response = "Executing: \(command)"
        responses.append(response)
        command = ""
    }
}
