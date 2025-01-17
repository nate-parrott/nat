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
}
