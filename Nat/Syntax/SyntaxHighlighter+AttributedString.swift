import Foundation
import SwiftUI

extension TokenRun {
    /// Convert a token run to an AttributedString with appropriate styling
    public func toAttributedString() -> AttributedString {
        var string = AttributedString(text)
        guard let type = tokenType else { return string }
        
        // Apply basic styling based on token type
        switch type {
        case .comment:
            string.foregroundColor = .gray
        case .string:
            string.foregroundColor = .red
        case .numberLiteral, .booleanLiteral:
            string.foregroundColor = .purple
        case .keyword:
            string.foregroundColor = .blue
        case .identifier:
            string.foregroundColor = .primary
        case .operatorToken:
            string.foregroundColor = .orange
        case .typeIdentifier:
            string.foregroundColor = .blue
        }
        
        return string
    }
}

extension Array where Element == TokenRun {
    /// Convert an array of token runs to a single AttributedString
    public func toAttributedString() -> AttributedString {
        self.map { $0.toAttributedString() }.reduce(AttributedString()) { $0 + $1 }
    }
}

struct WithSyntaxHighlightedLines<V: View>: View {
    var text: String
    var fileExtension: String?
    var font: Font
    @ViewBuilder var content: ([AttributedString]) -> V
    
    var body: some View {
        WithCacheSync(input: SyntaxHighlightInputs(text: text, fileExtension: fileExtension, font: font), compute: { $0.highlightedLines }) { lines in
            content(lines)
        }
    }
}

private struct SyntaxHighlightInputs: Equatable {
    var text: String
    var fileExtension: String?
    var font: Font
    
    var highlightedLines: [AttributedString] {
        var attributed = LanguagePack.fromFileExtension(fileExtension).tokenize(text).toAttributedString()
        attributed.font = font
        return attributed.lines
    }
}

extension AttributedString {
    var lines: [AttributedString] {
        split(separator: "\n")
    }
    
    func split(separator: Character) -> [AttributedString] {
        var results: [AttributedString] = []
        var currentString = self
        
        while let newlineRange = currentString.range(of: String(separator)) {
            // Add everything before the newline
            results.append(AttributedString(currentString[..<newlineRange.lowerBound]))
            
            // Move past the newline
            currentString.removeSubrange(..<newlineRange.upperBound)
        }
        
        // Add the remaining text
        if currentString.characters.count > 0 {
            results.append(currentString)
        }
        
        return results
    }
}
