import Foundation

//struct TimelineItem: Equatable, Identifiable {
//    var id: String
//    var icon: String?
//    var content: Content
//    
//    enum Content: Equatable {
//        case chat(ChatPage)
//        case terminal(
//    }
//}
//
//extension ThreadModel {
//    
//}

//import Foundation
//import ChatToys
//
//struct MessageCellModel: Equatable, Identifiable {
//    var id: String
//    var content: Content
//
//    enum Content: Equatable {
//        case userMessage(String)
//        case assistantMessage(String)
//        case toolLog(UserVisibleLog)
//        case codeEdit(CodeEdit)
//        case error(String)
//    }
//}
//
//extension ThreadModel {
//    var cellModels: [MessageCellModel] {
//        var cells = [MessageCellModel]()
//        for step in steps {
//            cells.append(MessageCellModel(id: step.id + "/initial", content: .userMessage(step.initialRequest.asPlainText(includeSystemMessages: false))))
//            for (i, loopItem) in step.toolUseLoop.enumerated() {
//                cells += loopItem.cellModels(idPrefix: step.id + "/toolUseLoop/\(i)/")
//            }
//            if let last = step.assistantMessageForUser {
//                cells += last.cellModels(idPrefix: step.id + "last/")
////                cells.append(MessageCellModel(id: step.id + "/last", content: .assistantMessage(last.asPlainText)))
//            }
//        }
//        if case .stoppedWithError(let err) = status {
//            cells.append(MessageCellModel(id: "error", content: .error(err)))
//        }
//        return cells
//    }
//}
//
//private extension ThreadModel.Step.ToolUseStep {
//    func cellModels(idPrefix: String) -> [MessageCellModel] {
//        var cells = [MessageCellModel]()
//        cells += initialResponse.cellModels(idPrefix: idPrefix + "/initial/")
////        if let text = initialResponse.asPlainText.nilIfEmpty {
////            cells.append(MessageCellModel(id: idPrefix + "initial", content: .assistantMessage(text.trimmingCharacters(in: .whitespacesAndNewlines))))
////        }
//        for (j, log) in userVisibleLogs.enumerated() {
//            cells.append(MessageCellModel(id: idPrefix + "logs/\(j)", content: .toolLog(log)))
//        }
//        return cells
//    }
//}
//
//private extension TaggedLLMMessage {
//    func cellModels(idPrefix: String) -> [MessageCellModel] {
//        if content.count == 1, let item = content.first, case .text(let string) = item, let parsed = try? EditParser.parsePartial(string: string) {
//            return parsed.enumerated().map { (i, item) in
//                switch item {
//                case .codeEdit(let edit):
//                    return MessageCellModel(id: idPrefix + "\(i)", content: .codeEdit(edit))
//                case .textLines(let lines):
//                    return MessageCellModel(id: idPrefix + "\(i)", content: .assistantMessage(lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
//                }
//            }
//        }
//        return [MessageCellModel(id: idPrefix + "text", content: .assistantMessage(asPlainText))]
//    }
//}
//
//extension LLMMessage {
//    var contentDescription: String {
//        var parts = [String]()
//        if let content = content.nilIfEmpty {
//            parts.append(content)
//        }
//        if images.count > 0 {
//            if images.count == 1 {
//                parts.append("[1 image]")
//            } else {
//                parts.append("[\(images.count) images]")
//            }
//        }
//        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
//    }
//}
