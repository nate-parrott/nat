import SwiftUI

struct FileDropModifier: ViewModifier {
    let projectFolder: URL?
    @Binding var attachments: [ChatAttachment]
    
    func body(content: Content) -> some View {
        content.onDrop(of: [.fileURL], isTargeted: nil) { providers in
            Task { @MainActor in
                for item in providers {
                    guard let urlIdentifier = item.registeredTypeIdentifiers.first else { continue }
                    
                    item.loadItem(forTypeIdentifier: urlIdentifier) { urlData, error in
                        guard error == nil,
                              let urlData = urlData as? Data,
                              let url = URL(dataRepresentation: urlData, relativeTo: nil),
                              ["jpg", "jpeg", "png", "gif", "heic"].contains(url.pathExtension.lowercased()) else { return }
                        
                        Task { @MainActor in
                            if let item = try? await ContextItem.from(url: url, projectFolder: projectFolder) {
                                attachments.append(ChatAttachment(id: UUID().description, contextItem: item))
                            }
                        }
                    }
                }
            }
            return true
        }
    }
}

extension View {
    func fileDropTarget(projectFolder: URL?, attachments: Binding<[ChatAttachment]>) -> some View {
        modifier(FileDropModifier(projectFolder: projectFolder, attachments: attachments))
    }
}
