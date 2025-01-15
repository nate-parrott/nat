import Foundation
import ChatToys

struct MessageCellModel: Equatable, Identifiable {
    var id: String
    var content: Content

    enum Content: Equatable {
        case userMessage(String)
        case assistantMessage(String)
        case toolLog(UserVisibleLog)
        case error(String)
    }
}

extension ThreadModel {
    var cellModels: [MessageCellModel] {
        var cells = [MessageCellModel]()
        for step in steps {
            cells.append(MessageCellModel(id: step.id + "/initial", content: .userMessage(step.initialRequest.contentDescription)))
            for (i, loopItem) in step.toolUseLoop.enumerated() {
                if let text = loopItem.initialResponse.content.nilIfEmpty {
                    cells.append(MessageCellModel(id: step.id + "/tools/\(i)/initial", content: .assistantMessage(text.trimmingCharacters(in: .whitespacesAndNewlines))))
                }
                for (j, log) in loopItem.userVisibleLogs.enumerated() {
                    cells.append(MessageCellModel(id: step.id + "/tools/\(i)/logs/\(j)", content: .toolLog(log)))
                }
            }
            if let last = step.assistantMessageForUser {
                cells.append(MessageCellModel(id: step.id + "/last", content: .assistantMessage(last.contentDescription)))
            }
        }
        if let lastError {
            cells.append(MessageCellModel(id: "error", content: .error(lastError)))
        }
        return cells
    }
}

extension LLMMessage {
    fileprivate var contentDescription: String {
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
