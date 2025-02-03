import SwiftUI

struct DiffView: View {
    var diff: Diff
    @State private var expansionIndices = Set<Int>()
    
    let verticalPad: CGFloat = 1

    var body: some View {
        // TODO: collapse multiline text fields
        ForEach(Array(diff.lines.enumerated()), id: \.offset) { pair in
            Group {
                switch pair.element {
                case .delete(let str):
                    Text(str)
                        .strikethrough()
                        .padding(.horizontal)
                        .padding(.vertical, verticalPad)
                        .background(Color.red.opacity(0.3))
                        .textSelection(.enabled)
                case .same(let str):
                    Text(str)
                        .padding(.horizontal)
                        .padding(.vertical, verticalPad)
                        .textSelection(.enabled)
                case .insert(let str):
                    Text(str)
//                        .foregroundStyle(Color.newCodeGreen)
                        .padding(.vertical, verticalPad)
                        .padding(.horizontal)
                        .background(Color.green.opacity(0.3))
                        .textSelection(.enabled)
                case .collapsed(let lines):
                    if expansionIndices.contains(pair.offset) {
                        DiffView(diff: Diff(lines: lines))
                            .padding(.vertical, verticalPad)
                    } else {
                        Label("\(lines.count) lines hidden", systemImage: "plus")
                            .opacity(0.5)
                            .onTapGesture {
                                expansionIndices.insert(pair.offset)
                            }
                            .padding(.vertical, verticalPad)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

