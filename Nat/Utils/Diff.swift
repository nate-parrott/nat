import SwiftUI

struct Diff: Equatable {
    enum Line: Equatable {
        case same(String)
        case insert(String)
        case delete(String)
    }

    var lines: [Line]

    func asText(font: Font) -> Text {
        var text = Text("")
        for line in lines {
            switch line {
            case .same(let string):
                text = text + Text(" \(string)\n").foregroundStyle(.primary)
            case .insert(let string):
                text = text + Text("+\(string)\n").foregroundStyle(.green)
            case .delete(let string):
                text = text + Text("-\(string)\n").foregroundStyle(.red)
            }
        }
        return text
    }
}
