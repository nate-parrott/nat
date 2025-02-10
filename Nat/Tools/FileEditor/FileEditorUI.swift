import Foundation
import SwiftUI

enum FileEditorReviewPanelResult: Equatable, Codable {
    case accept
    case acceptWithComment(String)
    case reject
    case requestChanged(String)
    
    var accepted: Bool {
        switch self {
        case .accept, .acceptWithComment: return true
        case .reject, .requestChanged: return false
        }
    }
    
    var comment: String? {
        // Written by Phil
        switch self {
        case .accept:
            return nil
        case .acceptWithComment(let comment), .requestChanged(let comment):
            return comment
        case .reject:
            return nil
        }
    }
}

struct DescribedDiff {
    var description: String
    var diff: Diff
}

// Shows a single diff with its description header
private struct DiffEditView: View {
    let describedDiff: DescribedDiff
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(describedDiff.description)
                .multilineTextAlignment(.leading)
                .font(.headline)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thickMaterial)
            
            Divider()

            VStack(alignment: .leading, spacing: 0) {
                DiffView(diff: describedDiff.diff)
                    .lineLimit(nil)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical)
        }
    }
}
// Review action buttons and comment input
private struct ReviewActionBar: View {
    @Binding var commentText: String
    var onApprove: (String) -> Void
    var onReject: (String) -> Void
    @State private var focusDate: Date?
    @State private var dictationState = DictationClient.State.none
    @State private var inputSize = CGSize.zero

    var body: some View {
        HStack {
            InputTextField(
                text: $commentText,
                options: .init(
                    placeholder: "Comment (optional)",
                    font: .systemFont(ofSize: 14),
                    insets: .init(width: 12, height: 21)
                ),
                focusDate: focusDate,
                onEvent: { _ in },
                contentSize: $inputSize
            )
            .modifier(DictationModifier(priority: 2, state: $dictationState, onDictatedText: { text in
                if self.commentText == "" {
                    self.commentText = text
                } else {
                    self.commentText += " " + text
                }
            }))
            .frame(height: max(60, inputSize.height))
            
            HStack {
                Button(action: { onApprove(commentText) }) {
                    Text("Approve")
                }
                .buttonStyle(ShinyButtonStyle(tintColor: .approveGreen))
                
                Button(action: { onReject(commentText) }) {
                    Text("Reject")
                }
                .buttonStyle(ShinyButtonStyle(tintColor: .red.opacity(0.8)))
            }
            .padding(6)
            .padding(.trailing, 8)
        }
        .dictationUI(state: dictationState)
        .onAppear {
            focusDate = Date()
        }
    }
}

struct FileEditorReviewPanel: View {
    var edits: [FileEdit]
    var finish: (FileEditorReviewPanelResult) -> Void
    
    var body: some View {
        let describedDiffs = edits.map { edit in 
            DescribedDiff(
                description: edit.description,
                diff: (try? edit.asDiff()) ?? Diff(lines: [])
            )
        }
        _DiffReviewPanel(diffs: describedDiffs, finish: finish)
    }
}

/// Internal view that handles the UI for reviewing diffs
private struct _DiffReviewPanel: View {
    var diffs: [DescribedDiff]
    var finish: (FileEditorReviewPanelResult) -> Void
    
    @State private var commentText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diffs.enumerated()), id: \.offset) { i, diff in
                        DiffEditView(describedDiff: diff)
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
        .background(.thickMaterial)
    }
}

// FUCK YOU SWIFTUI PREVIEWS!!!
//struct FileEditorReviewPanel_Previews: PreviewProvider {
//}

struct _FileEditorDemo: View {
    static var sampleDescribedDiff: DescribedDiff {
        DescribedDiff(
            description: "Change value type from Int to String",
            diff: Diff(lines: [
                .collapsed([.same("Line 1"), .same("Line 2")]),
                .same("struct Example {"),
                .delete("    var oldValue: Int"),
                .delete("    var oldValue: Int"),
                .insert("    var newValue: String"),
                .insert("    var newValue: String"),
                .insert("    var newValue: String"),
                .same("}")
            ])
        )
    }
    
    static var sampleDescribedDiff2: DescribedDiff {
        DescribedDiff(
            description: "Edit files/xyz.html",
            diff: Diff(lines: [
                .same("struct Example {"),
                .delete("    var oldValue: Int"),
                .insert("    var newValue: String"),
                .same("}")
            ])
        )
    }
    
    var body: some View {
        _DiffReviewPanel(
            diffs: [Self.sampleDescribedDiff, Self.sampleDescribedDiff2],
            finish: { _ in }
        )
    }
}
