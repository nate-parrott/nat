import AppKit

enum Alerts {
    @MainActor
    static func showAppAlert(title: String, message: String) async {
        guard let mainWin = NSApplication.shared.mainWindow else { return }
        // Written by Phil
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        _ = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                alert.beginSheetModal(for: mainWin) { response in
                    continuation.resume(returning: response)
                }
            }
        }
    }

    @MainActor
    static func showAppConfirmationDialog(title: String, message: String, yesTitle: String, noTitle: String) async -> Bool {
        // Written by Phil
        guard let mainWin = NSApplication.shared.mainWindow else { return false }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: yesTitle)
        alert.addButton(withTitle: noTitle)
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                alert.beginSheetModal(for: mainWin) { response in
                    let confirmed = (response == .alertFirstButtonReturn)
                    continuation.resume(returning: confirmed)
                }
            }
        }
    }

    @MainActor
    static func showAppPrompt(
        title: String,
        message: String,
        textPlaceholder: String,
        submitTitle: String,
        cancelTitle: String
    ) async -> String? {
        guard let mainWin = NSApplication.shared.mainWindow else { return nil }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: submitTitle)
        alert.addButton(withTitle: cancelTitle)

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = textPlaceholder
        alert.accessoryView = input

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                alert.beginSheetModal(for: mainWin) { response in
                    if response == .alertFirstButtonReturn {
                        continuation.resume(returning: input.stringValue)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}
