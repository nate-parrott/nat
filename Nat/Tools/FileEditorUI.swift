import Foundation
import SwiftUI

enum FileEditorReviewPanelResult: Equatable {
    case accept
    case reject
    case requestChanged(String)
}

struct FileEditorReviewPanel: View {
    var path: URL
    var edit: CodeEdit
    var finish: (FileEditorReviewPanelResult) -> Void

    @State private var diffText: Text?

    var body: some View {
        // TODO: Present diff
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(edit.description)
                    .multilineTextAlignment(.leading)
                    .font(.headline)
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thickMaterial)

                Divider()

                ScrollView {
                    diffText
                    .lineLimit(nil)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onAppear {
                diffText = try? edit.asDiff(filePath: path).asText(font: Font.system(size: 14, weight: .regular, design: .monospaced))
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

extension CodeEdit {
    func asDiff(filePath: URL) throws -> Diff {
        switch self {
        case .replace(let path, let lineRangeStart, let len, let content):
            let existingContent = try String(contentsOf: filePath, encoding: .utf8)
            let existingLines = existingContent.components(separatedBy: .newlines)
            let newLines = content.components(separatedBy: .newlines)

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
        case .create(let path, let content):
            let newLines = content.components(separatedBy: .newlines)
            var diff = Diff(lines: [])
            for newLine in newLines {
                diff.lines.append(.insert(newLine))
            }
            return diff
        }
    }
}
