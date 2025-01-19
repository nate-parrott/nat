import Foundation
import SwiftUI

enum FileEditorReviewPanelResult: Equatable {
    case accept
    case reject
    case requestChanged(String)
}

struct FileEditorReviewPanel: View {
    var edits: [FileEdit]
    var finish: (FileEditorReviewPanelResult) -> Void

    @State private var diffs: [Diff] = [] // one for each edit

    var body: some View {
        // TODO: Present diff
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(edits.enumerated()), id: \.offset) { pair in
                        let (i, edit) = pair
                        let diff: Diff = i < diffs.count ? diffs[i] : Diff(lines: [])
                        
                        Text(edit.description)
                            .multilineTextAlignment(.leading)
                            .font(.headline)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.thickMaterial)
                        
                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            DiffView(diff: diff)
                                .lineLimit(nil)
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                }
            }
            .onAppear {
                diffs = []
                for edit in edits {
                    diffs.append((try? edit.asDiff()) ?? Diff(lines: []))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { finish(.reject) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") { finish(.accept) }
                }
            }
            .navigationTitle("Review Changes")
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

extension FileEdit {
    func asDiff() throws -> Diff {
        if edits.count == 0 { return .init(lines: []) }
        if edits.count == 1, case .create(path: _, content: let content) = edits[0] {
            let newLines = content.lines
            var diff = Diff(lines: [])
            for newLine in newLines {
                diff.lines.append(.insert(newLine))
            }
            return diff
        }

        var editsByStartLine = [Int: CodeEdit]()
        for edit in edits {
            switch edit {
            case .replace(_, let lineRangeStart, _, _):
                editsByStartLine[lineRangeStart] = edit
            case .create: () // skip, unexpected
            }
        }

        var lines = [Diff.Line]()
        var remainingSourceLines = try String(contentsOf: path, encoding: .utf8).lines
        while remainingSourceLines.count > 0 {
            if let editNow = editsByStartLine[lines.count] {
                switch editNow {
                case .create: fatalError()
                case .replace(path: _, lineRangeStart: _, lineRangeLen: let deletionLen, content: let content):
                    lines += content.lines.map({ Diff.Line.insert($0) })
                    for deletedLine in remainingSourceLines.prefix(deletionLen) {
                        lines.append(.delete(deletedLine))
                    }
                    remainingSourceLines = remainingSourceLines.dropFirst(deletionLen).asArray
                }
            } else {
                lines.append(.same(remainingSourceLines.removeFirst()))
            }
        }

        return Diff(lines: lines)
    }
}

extension CodeEdit {
    func asDiff(filePath: URL) throws -> Diff {
        switch self {
        case .replace(_, let lineRangeStart, let len, let content):
            let existingContent = try String(contentsOf: filePath, encoding: .utf8)
            let existingLines = existingContent.lines
            let newLines = content.lines

            var diff = Diff(lines: [])
            for (i, existingLine) in existingLines.enumerated() {
                if i == lineRangeStart {
                   for newLine in newLines {
                       diff.lines.append(.insert(newLine))
                   }
                }
                if i >= lineRangeStart && i < lineRangeStart + len {
                    diff.lines.append(.delete(existingLine))
                } else {
                    diff.lines.append(.same(existingLine))
                }
            }
            return diff
        case .create(_, let content):
            let newLines = content.lines
            var diff = Diff(lines: [])
            for newLine in newLines {
                diff.lines.append(.insert(newLine))
            }
            return diff
        }
    }
}

//extension FileEdit {
//    
//}
