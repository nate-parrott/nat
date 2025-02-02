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
    }
}
