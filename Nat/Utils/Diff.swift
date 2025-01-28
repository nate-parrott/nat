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

extension Diff {
    static func from(before: [String], after: [String], collapseSames: Bool) -> Diff {
        let diff = after.difference(from: before).asArray

        // An important aspect of this is that the iteration will happen in a specific order: First, all the removals from highest to lowest offset, followed by insertions from lowest to highest

        func isSame(_ line: Diff.Line) -> Bool {
            switch line {
            case .same: return true
            default: return false
            }
        }

        // Our diff has more lines than the `after` collection b/c it includes deletions.
        // So we use an array of arrays, where lines[x] is equal to output_array[x],
        // but we can store multiple items per line
        var groups: [[Diff.Line]] = before.map({ [Diff.Line.same($0)] })
        var endGroup = [Diff.Line]()
        for edit in diff {
            switch edit {
            case .insert(offset: let idx, element: let element, associatedWith: _):
                groups.insert([.insert(element)], at: idx)
            case .remove(offset: let idx, element: let element, associatedWith: _):
                let remainingItems = groups[idx].filter({ !isSame($0) }) + [.delete(element)]
                groups.remove(at: idx)
                // remainingItems will typically be the delete from the line we just deleted, but may also include other cascaded deletes
                // Insert at subsequent group
                if idx < groups.count {
                    groups[idx].insert(contentsOf: remainingItems, at: 0)
                } else {
                    endGroup.insert(contentsOf: remainingItems, at: 0)
                }
            }
        }
        var items = (groups + [endGroup]).flatMap({ $0 })
        if collapseSames {
            items = Diff.collapseRunsOfSames(items)
        }
        return .init(lines: items)
    }
}
