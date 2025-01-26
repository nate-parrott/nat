import Foundation

extension FileEdit {
    func asDiff() throws -> Diff {
        if edits.count == 0 { return .init(lines: []) }

        let (before, after) = try getBeforeAfter()
        return Diff.from(before: before.lines, after: after.lines, collapseSames: true)
//        if edits.count == 1, case .create(path: _, content: let content) = edits[0] {
//            let newLines = content.lines
//            var diff = Diff(lines: [])
//            for newLine in newLines {
//                diff.lines.append(.insert(newLine))
//            }
//            return diff
//        }


//        var patches = patch(from: before.lines, to: after.lines)
//
//        var editsByStartLine = [Int: [Patch<String>]]()
//        for patch in patches {
//            switch patch {
//            case .deletion(index: let idx):
//                editsByStartLine[idx, default: []].append(patch)
//            case .insertion(index: let idx, element: _):
//                editsByStartLine[idx, default: []].append(patch)
//            }
//        }
//
//        var diffLines = [Diff.Line]()
//        var outIndex = 0
//        for sourceLine in before.lines {
//            // First, process inserts/deletes:
//            while let edits = editsByStartLine[outIndex] {
//                for edit in edits {
//                    switch edit {
//                    case .deletion(index: let idx):
//                        diffLines.append(.delete(<#T##String#>))
//                    }
//                }
//            }
//        }

//
//        var lines = [Diff.Line]()
//        var linesOfOutput = 0
//        var remainingSourceLines = try String(contentsOf: path, encoding: .utf8).lines
//        while remainingSourceLines.count > 0 {
//            if let editNow = editsByStartLine[linesOfOutput] {
//                switch editNow {
//                case .create: fatalError()
//                case .replace(path: _, lineRangeStart: _, lineRangeLen: let deletionLen, lines: let newLines):
//                    for deletedLine in remainingSourceLines.prefix(deletionLen) {
//                        lines.append(.delete(deletedLine))
//                    }
//                    lines += newLines.map({ Diff.Line.insert($0) })
//                    linesOfOutput += newLines.count
//                    remainingSourceLines = remainingSourceLines.dropFirst(deletionLen).asArray
//                }
//            } else {
//                lines.append(.same(remainingSourceLines.removeFirst()))
//                linesOfOutput += 1
//            }
//        }
//
//        return Diff(lines: Diff.collapseRunsOfSames(lines))
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
