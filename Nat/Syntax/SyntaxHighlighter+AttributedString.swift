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