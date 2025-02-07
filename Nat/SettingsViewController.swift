import AppKit
import SwiftUI

class SettingsViewController: NSViewController {
    let rootVC = NSHostingController(rootView: SettingsContentView())
    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(rootVC)
        view.addSubview(rootVC.view)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        rootVC.view.frame = view.bounds
    }
}

struct SettingsContentView: View {
    @AppStorage(DefaultsKeys.openrouterKey.rawValue) private var openrouterKey = ""
    @AppStorage(DefaultsKeys.openAIKey.rawValue) private var openAIKey = ""
    
    var body: some View {
        Form {
            Section("API Keys") {
                TextField("OpenRouter Key", text: $openrouterKey)
                TextField("OpenAI Key (required for dictation)", text: $openAIKey)
            }
        }
        .formStyle(.grouped)
    }
}
