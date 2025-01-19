import SwiftUI

struct Diff: Equatable {
    enum Line: Equatable {
        case same(String)
        case insert(String)
        case delete(String)
        case collapsed([Line])
    }

    var lines: [Line]

//    func asText(font: Font) -> Text {
//        var text = Text("")
//        for line in lines {
//            switch line {
//            case .same(let string):
//                text = text + Text(" \(string)\n").foregroundStyle(.primary)
//            case .insert(let string):
//                text = text + Text("+\(string)\n").foregroundStyle(.green)
//            case .delete(let string):
//                text = text + Text("-\(string)\n").foregroundStyle(.red)
//            }
//        }
//        return text
//    }
}

struct DiffView: View {
    var diff: Diff
    @State private var expansionIndices = Set<Int>()

    var body: some View {
        // TODO: collapse multiline text fields
        ForEach(Array(diff.lines.enumerated()), id: \.offset) { pair in
            switch pair.element {
            case .delete(let str):
                Text(str).foregroundStyle(.red)
            case .same(let str):
                Text(str)
            case .insert(let str):
                Text(str).foregroundStyle(.green)
            case .collapsed(let lines):
                if expansionIndices.contains(pair.offset) {
                    DiffView(diff: Diff(lines: lines))
                } else {
                    Label("Show \(lines.count) lines", systemImage: "plus.circle")
                        .foregroundStyle(.blue)
                        .onTapGesture {
                            expansionIndices.insert(pair.offset)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
