import Foundation
import SwiftUI

enum FileEditorReviewPanelResult: Equatable {
    case accept
    case acceptWithComment(String)
    case reject
    case requestChanged(String)
}
// Shows a single diff with its description header
private struct DiffEditView: View {
    let edit: FileEdit
    let diff: Diff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

// Review action buttons and comment input
private struct ReviewActionBar: View {
    @Binding var commentText: String
    var onApprove: (String) -> Void
    var onReject: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            InputTextField(
                text: $commentText,
                options: .init(
                    placeholder: "Add a comment (optional)",
                    font: .systemFont(ofSize: 14),
                    insets: .init(width: 12, height: 21)
                ),
                focusDate: nil,
                onEvent: { _ in },
                contentSize: .constant(.zero)
            )
            .frame(height: 60)
            
            Button(action: { onApprove(commentText) }) {
                Text("Approve")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { onReject(commentText) }) {
                Text("Reject")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
}

struct FileEditorReviewPanel: View {
    var edits: [FileEdit]
    var finish: (FileEditorReviewPanelResult) -> Void

    @State private var diffs: [Diff] = []
    @State private var commentText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(edits.enumerated()), id: \.offset) { pair in
                            let (i, edit) = pair
                            let diff: Diff = i < diffs.count ? diffs[i] : Diff(lines: [])
                            DiffEditView(edit: edit, diff: diff)
                        }
                    }
                }
                
                Divider()
                
                ReviewActionBar(
                    commentText: $commentText,
                    onApprove: { comment in
                        if comment.isEmpty {
                            finish(.accept)
                        } else {
                            finish(.acceptWithComment(comment))
                        }
                    },
                    onReject: { comment in
                        if comment.isEmpty {
                            finish(.reject)
                        } else {
                            finish(.requestChanged(comment))
                        }
                    }
                )
            }
            .onAppear {
                diffs = []
                for edit in edits {
                    diffs.append((try? edit.asDiff()) ?? Diff(lines: []))
                }
            }
            .navigationTitle("Review Changes")
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

extension FileEdit {
    func asDiff() throws -> Diff {
        // TODO
        fatalError()

//        if edits.count == 0 { return .init(lines: []) }
//        if edits.count == 1, case .create(path: _, content: let content) = edits[0] {
//            let newLines = content.lines
//            var diff = Diff(lines: [])
//            for newLine in newLines {
//                diff.lines.append(.insert(newLine))
//            }
//            return diff
//        }
//
//        var editsByStartLine = [Int: CodeEdit]()
//        for edit in edits {
//            switch edit {
//            case .replace(_, let lineRangeStart, _, _):
//                editsByStartLine[lineRangeStart] = edit
//            case .create: () // skip, unexpected
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
