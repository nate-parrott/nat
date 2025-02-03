import Foundation
import ChatToys

struct MessageCellModel: Equatable, Identifiable {
    var id: String
    var content: Content

    enum Content: Equatable {
        case userMessage(String)
        case assistantMessage(String)
        case logs([UserVisibleLog]) // Logs can be clustered together
        case codeEdit(CodeEdit)
        case error(String)
    }
}

extension ThreadModel {
    var cellModels: [MessageCellModel] {
        var cells = [MessageCellModel]()
        for step in steps {
            cells.append(MessageCellModel(id: step.id + "/initial", content: .userMessage(step.initialRequest.asPlainText(includeSystemMessages: false))))
            for (i, loopItem) in step.toolUseLoop.enumerated() {
                cells += loopItem.cellModels(idPrefix: step.id + "/toolUseLoop/\(i)/")
            }
            if let last = step.assistantMessageForUser {
                cells += last.assistantCellModels(idPrefix: step.id + "last/")
            }
        }
        if case .stoppedWithError(let err) = status {
            cells.append(MessageCellModel(id: "error", content: .error(err)))
        }
        cells = clusterLogs(cells)
        return cells
    }
}

private extension ThreadModel.Step.ToolUseStep {
    func cellModels(idPrefix: String) -> [MessageCellModel] {
        var cells = [MessageCellModel]()
        cells += initialResponse.assistantCellModels(idPrefix: idPrefix + "/initial/")
        for (j, log) in allLogs.enumerated() {
            cells.append(MessageCellModel(id: idPrefix + "logs/\(j)", content: .logs([log])))
        }
        return cells
    }
}

extension TaggedLLMMessage {
    func assistantCellModels(idPrefix: String) -> [MessageCellModel] {
        if content.count == 1, let item = content.first, case .text(let string) = item, let parsed = try? EditParser.parsePartial(string: string) {
            return parsed.enumerated().map { (i, item) in
                switch item {
                case .codeEdit(let edit):
                    return MessageCellModel(id: idPrefix + "\(i)", content: .codeEdit(edit))
                case .textLines(let lines):
                    return MessageCellModel(id: idPrefix + "\(i)", content: .assistantMessage(lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }
        return [MessageCellModel(id: idPrefix + "text", content: .assistantMessage(asPlainText))]
    }
}

extension LLMMessage {
    var contentDescription: String {
        var parts = [String]()
        if let content = content.nilIfEmpty {
            parts.append(content)
        }
        if images.count > 0 {
            if images.count == 1 {
                parts.append("[1 image]")
            } else {
                parts.append("[\(images.count) images]")
            }
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension UserVisibleLog {
    func canClusterWith(prevItems: [UserVisibleLog]) -> Bool {
        guard let first = prevItems.first else { return false }
        switch self {
        case .codeSearch, .effort, .readFile, .listedFiles, .grepped:
            if case .codeSearch = first {
                return true
            }
        default: ()
        }
        return false
    }
}

func clusterLogs(_ cells: [MessageCellModel]) -> [MessageCellModel] {
    var results = [MessageCellModel]()
    
    for cell in cells {
        if case .logs(let logs) = cell.content, logs.count == 1, let last = results.last, case .logs(let prevLogs) = last.content, logs[0].canClusterWith(prevItems: prevLogs) {
            results[results.count - 1] = .init(id: last.id, content: .logs(prevLogs + logs))
        } else {
            results.append(cell)
        }
    }
    
    return results
}
