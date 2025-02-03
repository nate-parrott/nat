import Foundation

extension MessageCellModel {
    var backdrop: TimelineBackdrop? {
        switch content {
        case .codeEdit(let edit): return .editFile(edit)
        case .toolLog(.readFile(let url)): return .viewFile(url)
        case .toolLog(.terminal): return .terminal
        default: return nil
        }
    }
    
    var markerInTimeline: (name: String, icon: String)? {
        if case .userMessage(let str) = content {
            return (str.truncateHeadWithEllipsis(chars: 40), "bubble.fill")
        }
        if case .codeEdit(let edit) = content {
            return (edit.url.lastPathComponent, "keyboard")
        }
        return nil
    }
}

enum TimelineBackdrop: Equatable {
    case terminal
    case viewFile(URL)
    case editFile(CodeEdit)
}

struct TimelineItem: Equatable, Identifiable {
    var id: String
    var backdrop: TimelineBackdrop?
    var markerName: String?
    var markerIcon: String?
    var messages: [MessageCellModel]
    
    var isNotEmpty: Bool {
        backdrop != nil || messages.count > 0
    }
}

extension ThreadModel {
    func timelineItems() -> [TimelineItem] {
        var items = [TimelineItem]()
        var currentItem = TimelineItem(id: "initial", messages: [])
        func newItem(id: String) {
            if currentItem.isNotEmpty{
                items.append(currentItem)
            }
            currentItem = .init(id: id, messages: [])
        }
        let cellModels = self.cellModels
        for (i, cell) in cellModels.enumerated() {
            let blankPage = cell.backdrop != nil || cell.markerInTimeline != nil
            if blankPage {
                newItem(id: cell.id)
            }
            if let (name, icon) = cell.markerInTimeline {
                currentItem.markerIcon = icon
                currentItem.markerName = name
            }
            if let backdrop = cell.backdrop {
                currentItem.backdrop = backdrop
            }
            currentItem.messages.append(cell)
            if case .userMessage = cell.content, i > 0, case .assistantMessage = cellModels[i - 1].content, currentItem.messages.count == 1 {
                // Show assistant message from past page on this page, too
                currentItem.messages.insert(cellModels[i - 1], at: 0)
            }
        }
        if currentItem.isNotEmpty {
            items.append(currentItem)
        }
        return items
    }
}

