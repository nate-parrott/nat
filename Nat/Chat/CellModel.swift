import Foundation
import ChatToys

struct MessageCellModel: Equatable, Identifiable {
    var id: String
    var content: Content

    enum Content: Equatable {
        case userMessage(text: String, attachments: [ContextItem])
        case reasoning(String)
        case assistantMessage(String)
        case logs([UserVisibleLog]) // Logs can be clustered together
        case codeEdit(CodeEdit)
        case error(String)
    }
    
    static func idForUserMessage(stepIndex: Int) -> String {
        "\(stepIndex)/initialUserMsg"
    }
}

extension MessageCellModel.Content {
    var isUserMsg: Bool {
        if case .userMessage = self { return true }
        return false
    }
}

extension ThreadModel {
    var cellModels: [MessageCellModel] {
        var cells = [MessageCellModel]()
        for (i, step) in steps.enumerated() {
            // Generate cells from initial user message:
            let (initialText, initialAttachments) = step.initialRequest.spitPlaintextAndOtherContextItems
            cells.append(MessageCellModel(
                id: MessageCellModel.idForUserMessage(stepIndex: i),
                content: .userMessage(text: initialText, attachments: initialAttachments))
            )
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

extension TaggedLLMMessage {
    var spitPlaintextAndOtherContextItems: (String, [ContextItem]) {
        var plain = [String]()
        var other = [ContextItem]()
        for item in content {
            if case .text(let string) = item {
                plain.append(string)
            } else {
                other.append(item)
            }
        }
        return (plain.joined(separator: "\n\n"), other)
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
        var cells = [MessageCellModel]()
        if content.count == 1, let item = content.first, case .text(let string) = item, let parsed = try? EditParser.parsePartial(string: string) {
            if let r = reasoning?.nilIfEmpty {
                cells.append(MessageCellModel(id: idPrefix + "reasoning", content: .reasoning(r)))
            }
            cells += parsed.enumerated().map { (i, item) in
                switch item {
                case .codeEdit(let edit):
                    return MessageCellModel(id: idPrefix + "\(i)", content: .codeEdit(edit))
                case .textLines(let lines):
                    return MessageCellModel(id: idPrefix + "\(i)", content: .assistantMessage(lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            return cells
        }
        // Plaintext
        cells.append(MessageCellModel(id: idPrefix + "text", content: .assistantMessage(asPlainText)))
        return cells
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
        case .codeSearch, .effort, .listedFiles, .grepped:
            if case .codeSearch = first {
                return true
            }
        case .readFile:
            if case .readFile = first {
                return true
            }
            if case .codeSearch = first {
                return true
            }
        case .terminalSnapshot:
            // Allow merging terminal snapshots into a cluster where the first item is a terminal call
            if case .terminal = first {
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
