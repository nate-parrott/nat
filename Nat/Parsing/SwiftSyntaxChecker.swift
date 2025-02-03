import SwiftTreeSitter
import TreeSitterSwift

enum SyntaxCheckResult {
    case ok
    case failed(String)
}

func checkSwiftSyntax(code: String) async -> SyntaxCheckResult {
    // TODO
    fatalError()
}

//let swiftConfig = try LanguageConfiguration(tree_sitter_swift(), name: "Swift")
//
//let parser = Parser()
//try parser.setLanguage(swiftConfig.language)
