import SwiftUI

struct Diff: Equatable {
    enum Line: Equatable {
        case same(String)
        case insert(String)
        case delete(String)
        case collapsed([Line])
    }

    var lines: [Line]

    static func collapseRunsOfSames(_ lines: [Line]) -> [Line] {
        var result: [Line] = []
        var currentRun: [Line] = []

        func flushRun() {
            if currentRun.count >= 20 {
                // Keep first 5 and last 5 lines, collapse the rest
                let collapsedLines = Array(currentRun.dropFirst(5).dropLast(5))
                result.append(contentsOf: currentRun.prefix(5))
                result.append(.collapsed(collapsedLines))
                result.append(contentsOf: currentRun.suffix(5))
            } else {
                result.append(contentsOf: currentRun)
            }
            currentRun = []
        }

        for line in lines {
            if case .same = line {
                currentRun.append(line)
            } else {
                flushRun()
                result.append(line)
            }
        }

        flushRun() // Handle any remaining run at the end

        return result
    }
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
