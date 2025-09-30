# LaTeX Integration Guide

## Overview
This guide explains how to integrate proper LaTeX rendering into the CanvasAutomationFlow iOS app using LaTeXSwiftUI.

## Current Status
- ✅ Simplified LaTeX symbol conversion implemented
- ⏳ LaTeXSwiftUI package integration pending
- ⏳ Full LaTeX rendering implementation pending

## Step 1: Add LaTeXSwiftUI Package

### In Xcode:
1. Open `CanvasAutomationFlow.xcodeproj`
2. Go to **File** → **Add Package Dependencies**
3. Enter URL: `https://github.com/colinc86/LaTeXSwiftUI`
4. Click **Add Package**
5. Select the **CanvasAutomationFlow** target
6. Click **Add Package**

## Step 2: Update MathFormattedText.swift

Replace the current `IosMathView` implementation with:

```swift
import LaTeXSwiftUI

// Native iOS Math renderer using LaTeXSwiftUI
struct IosMathView: View {
    let latex: String
    
    var body: some View {
        LaTeX(latex)
            .parsingMode(.onlyEquations)
            .imageRenderingMode(.template)
            .errorMode(.original)
            .font(.system(size: 18))
    }
}
```

## Step 3: Alternative Libraries

If LaTeXSwiftUI doesn't meet your needs, consider:

### Option 1: LLMStream
```swift
import LLMStream

struct IosMathView: View {
    let latex: String
    
    var body: some View {
        LLMStreamView(content: "$$\(latex)$$")
    }
}
```

### Option 2: MarkdownLaTeX
```swift
import MarkdownLaTeX

struct IosMathView: View {
    let latex: String
    
    var body: some View {
        MarkdownLaTeXView("$$\(latex)$$")
    }
}
```

## Step 4: Testing

Test with various LaTeX expressions:

```swift
// In your preview or test code
MathFormattedText("""
## Math Examples

### Basic Operations
Addition: $2 + 3 = 5$
Subtraction: $5 - 2 = 3$

### Fractions
$$\frac{a}{b} + \frac{c}{d} = \frac{ad + bc}{bd}$$

### Greek Letters
$$\alpha + \beta = \gamma$$

### Complex Expressions
$$\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}$$

### Matrices
$$\begin{pmatrix}
a & b \\
c & d
\end{pmatrix}$$
""")
```

## Benefits of Using LaTeX Libraries

1. **Proper Rendering**: Mathematical expressions render correctly
2. **No Hardcoding**: No need to maintain symbol mappings
3. **Extensibility**: Support for complex LaTeX features
4. **Maintenance**: Libraries are maintained by the community
5. **Performance**: Optimized rendering engines

## Current Fallback

Until LaTeXSwiftUI is integrated, the app uses a simplified LaTeX-to-Unicode conversion that handles:
- Greek letters (α, β, γ, π, etc.)
- Mathematical symbols (∞, ∑, ∫, ∂, etc.)
- Operators (≤, ≥, ≠, ±, ×, ÷, etc.)
- Superscripts and subscripts (⁰¹²³, ₀₁₂₃)
- Basic fractions and square roots

## Next Steps

1. Add LaTeXSwiftUI package to Xcode project
2. Update `IosMathView` to use LaTeXSwiftUI
3. Test with complex mathematical expressions
4. Remove the simplified LaTeX conversion code
5. Update documentation and examples
