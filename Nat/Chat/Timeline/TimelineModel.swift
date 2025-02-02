//import Foundation
//
//struct TimelineItem: Equatable {
//    var icon: String?
//    
//    var chats: [MessageCellModel] // shown as overlay, except when content is nil
//    var background: Background?
//    
//    enum Background: Equatable {
//        case edit(CodeEdit)
//        case terminal
//    }
//    
//    struct CodeSearchVis: Equatable {
//        var queries: [String]
//        var greps: [String]
//        var files: [URL]
//    }
//}
//
//private extension TimelineItem {
//    var bgCodeSearchViz: CodeSearchVis? {
//        get {
//            if let background, case .codeSearch(let codeSearchVis) = background {
//                return codeSearchVis
//            }
//            return nil
//        }
//        set {
//            if let newValue {
//                background = .codeSearch(newValue)
//            }
//        }
//    }
//}
//
//extension ThreadModel {
//    func timelineItems() -> [TimelineItem] {
//        var items = [TimelineItem]()
//        var currentItem = TimelineItem(id: "0", chats: [])
//        
//        func startNewItem() {
//            if currentItem.chats.count > 0 || currentItem.background != nil {
//                items.append(currentItem)
//            }
//            currentItem = .init(id: "\(items.count)", chats: [])
//        }
//        
//        func modifyCodeSearchViz(_ block: (inout TimelineItem.CodeSearchVis) -> Void) {
//            if currentItem.background != nil {
//                startNewItem()
//            }
//            if currentItem.background == nil {
//                currentItem.background = .codeSearch(.init(queries: [], greps: [], files: []))
//            }
//            // Will always be true:
//            if var viz = currentItem.bgCodeSearchViz {
//                block(&viz)
//                currentItem.bgCodeSearchViz = viz
//            }
//        }
//        
//        for step in steps {
//            startNewItem() // new page for each user message
//            currentItem.icon = "text.bubble"
//            // TODO: Show attachments in chat
//            currentItem.chats.append(.init(id: step.id + "/initial", content: .userMessage(step.initialRequest.asPlainText(includeSystemMessages: false))))
//            
//            for (i, toolUseStep) in step.toolUseLoop.enumerated() {
//                let idPrefix = step.id + "/step/\(i)/"
//                
//                // Is this a file edit?
//                if toolUseStep.hasFileEdits, currentItem.background != .chatExclusive {
//                    // Go straight to chat
//                    startNewItem()
//                    currentItem = .chatExclusive
//                }
//                
//                currentItem.chats += toolUseStep.initialResponse.assistantCellModels(idPrefix: idPrefix)
//                                
//                for fnCall in toolUseStep.initialResponse.functionCalls {
//                    
//                }
//            }
//        }
//    }
//}
//
//
//private extension ThreadModel.Step.ToolUseStep {
//    var hasFileEdits: Bool {
//        for log in psuedoFunctionLogs {
//            switch log {
//            case .edits: return true
//            default: continue
//            }
//        }
//        return false
//    }
//}
