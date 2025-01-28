import Foundation

extension FileEdit {
    func asDiff() throws -> Diff {
        if edits.count == 0 { return .init(lines: []) }

        let (before, after) = try getBeforeAfter()
        return Diff.from(before: before.lines, after: after.lines, collapseSames: true)
    }
}

//
//extension CodeEdit {
//    func asDiff(filePath: URL) throws -> Diff {
//        switch self {
//        case .replace(_, let lineRangeStart, let len, let newLines):
//            let existingContent = try String(contentsOf: filePath, encoding: .utf8)
//            let existingLines = existingContent.lines
//
//            var diff = Diff(lines: [])
//            for (i, existingLine) in existingLines.enumerated() {
//                if i == lineRangeStart {
//                   for newLine in newLines {
//                       diff.lines.append(.insert(newLine))
//                   }
//                }
//                if i >= lineRangeStart && i < lineRangeStart + len {
//                    diff.lines.append(.delete(existingLine))
//                } else {
//                    diff.lines.append(.same(existingLine))
//                }
//            }
//            return diff
//        case .create(_, let content):
//            let newLines = content.lines
//            var diff = Diff(lines: [])
//            for newLine in newLines {
//                diff.lines.append(.insert(newLine))
//            }
//            return diff
//        }
//    }
//}

//extension FileEdit {
//
//}
