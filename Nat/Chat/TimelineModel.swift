//import Foundation
//
//struct TimelineItem: Equatable, Identifiable {
//    var id: String
//    var icon: String?
//    
//    var chats: [MessageCellModel] // shown as overlay, except when content is nil
//    var background: Background?
//    
//    enum Background: Equatable {
//        case terminal
//        case listFileTree
//        case codeSearch(CodeSearchVis)
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
//            startNewItem()
//            currentItem.icon = "text.bubble"
//            // TODO: Show attachments in chat
//            currentItem.chats.append(.init(id: step.id + "/initial", content: .userMessage(step.initialRequest.asPlainText(includeSystemMessages: false))))
//            
//            for (i, toolUseStep) in step.toolUseLoop.enumerated() {
//                let idPrefix = step.id + "/step/\(i)/"
//                currentItem.chats += toolUseStep.initialResponse.assistantCellModels(idPrefix: idPrefix)
//                for (j, log) in toolUseStep.userVisibleLogs.enumerated() {
//                    switch log {
//                    case .readFile(let url):
//                        modifyCodeSearchViz { viz in
//                            viz.files.append(url)
//                        }
//                    case .grepped(let string):
//                        modifyCodeSearchViz { viz in
//                            viz.greps.append(string)
//                        }
//                    case .edits:
//                        currentItem.chats.append(.init(id: idPrefix + "j", content: .toolLog(log)))
//                    case .webSearch(let string):
//                        <#code#>
//                    case .deletedFile(let uRL):
//                        <#code#>
//                    case .codeSearch(let string):
//                        <#code#>
//                    case .usingEditCleanupModel(let uRL):
//                        <#code#>
//                    case .listedFiles:
//                        <#code#>
//                    case .tokenUsage(let prompt, let completion, let model):
//                        <#code#>
//                    case .effort(let string):
//                        <#code#>
//                    case .toolWarning(let string):
//                        <#code#>
//                    case .toolError(let string):
//                        <#code#>
//                    case .terminal(let command):
//                        <#code#>
//                    }
//                }
//            }
//        }
//    }
//}
