import Foundation

/// Represents a semantic token in syntax highlighting
public enum SemanticTokenType {
    case comment
    case string
    case numberLiteral
    case booleanLiteral
    case keyword
    case identifier
    case operatorToken
    case typeIdentifier
}

/// A run of text with optional semantic meaning
public struct TokenRun {
    public let text: String
    public let tokenType: SemanticTokenType?
    
    public init(text: String, tokenType: SemanticTokenType?) {
        self.text = text
        self.tokenType = tokenType
    }
}

/// A language definition containing regex patterns mapped to semantic token types
public struct LanguagePack {
    public struct TokenPattern {
        let regex: NSRegularExpression
        let tokenType: SemanticTokenType
        
        public init(pattern: String, tokenType: SemanticTokenType) throws {
            self.regex = try NSRegularExpression(pattern: pattern, options: [])
            self.tokenType = tokenType
        }
    }
    
    private let patterns: [TokenPattern]
    
    public init(patterns: [TokenPattern]) {
        self.patterns = patterns
    }
    
    /// Return only the semantic tokens, dropping whitespace/unknown
    public func tokenizeSemanticOnly(_ input: String) -> [TokenRun] {
        tokenize(input).filter { $0.tokenType != nil }
    }
    
    /// Return the token types only, in sequence, dropping whitespace/unknown
    public func tokenizeTypes(_ input: String) -> [SemanticTokenType] {
        tokenizeSemanticOnly(input).compactMap { $0.tokenType }
    }
    
    /// Find the earliest match across all patterns
    private func findEarliestMatch(in string: String, range: NSRange) -> (match: NSTextCheckingResult, tokenType: SemanticTokenType)? {
        var bestMatch: (match: NSTextCheckingResult, tokenType: SemanticTokenType)? = nil
        
        for pattern in patterns {
            if let match = pattern.regex.firstMatch(in: string, range: range) {
                if let current = bestMatch {
                    if match.range.location < current.match.range.location {
                        bestMatch = (match, pattern.tokenType)
                    }
                } else {
                    bestMatch = (match, pattern.tokenType)
                }
            }
        }
        
        return bestMatch
    }
    
    /// Tokenize a string into semantic runs
    public func tokenize(_ input: String) -> [TokenRun] {
        var runs: [TokenRun] = []
        var currentIndex = 0
        
        while currentIndex < input.count {
            let remainingString = (input as NSString)
            let remainingRange = NSRange(location: currentIndex, length: remainingString.length - currentIndex)
            
            // Find the earliest match in remaining text
            if let (match, tokenType) = findEarliestMatch(in: input, range: remainingRange) {
                // If there's text before the match, add it as a non-semantic run
                if match.range.location > currentIndex {
                    let preMatchText = remainingString.substring(with: NSRange(location: currentIndex, length: match.range.location - currentIndex))
                    runs.append(TokenRun(text: preMatchText, tokenType: nil))
                }
                
                // Add the matched token
                let matchedText = remainingString.substring(with: match.range)
                runs.append(TokenRun(text: matchedText, tokenType: tokenType))
                
                currentIndex = match.range.location + match.range.length
            } else {
                // No more matches, add remaining text as non-semantic
                let remainingText = remainingString.substring(with: remainingRange)
                runs.append(TokenRun(text: remainingText, tokenType: nil))
                break
            }
        }
        
        return runs
    }
}

/// Sample Swift language pack
public extension LanguagePack {
    static var swift: LanguagePack {
        do {
            return try LanguagePack(patterns: [
                // Comments
                TokenPattern(pattern: "//[^\n]*", tokenType: .comment),
                TokenPattern(pattern: #"/\*([^*]|\*(?!/)|[\r\n])*\*/"#, tokenType: .comment),
                
                // Strings
                TokenPattern(pattern: #""[^"\\]*(?:\\.[^"\\]*)*""#, tokenType: .string),
                
                // Numbers
                TokenPattern(pattern: #"\b\d+(?:\.\d+)?\b"#, tokenType: .numberLiteral),
                
                // Booleans
                TokenPattern(pattern: #"\b(true|false)\b"#, tokenType: .booleanLiteral),
                
                // Keywords
                TokenPattern(pattern: #"\b(class|struct|enum|func|var|let|if|else|for|while|return|guard|switch|case|default|break|continue|throw|try|catch)\b"#, tokenType: .keyword),
                
                // Type identifiers (capitalized words)
                TokenPattern(pattern: #"\b[A-Z][a-zA-Z0-9]*\b"#, tokenType: .typeIdentifier),
                
                // Operators
                TokenPattern(pattern: #"[=+\-*/%&|^~!<>?]+"#, tokenType: .operatorToken),
                
                // Identifiers
                TokenPattern(pattern: #"\b[a-z][a-zA-Z0-9]*\b"#, tokenType: .identifier)
            ])
        } catch {
            fatalError("Failed to create Swift language pack: \(error)")
        }
    }
}