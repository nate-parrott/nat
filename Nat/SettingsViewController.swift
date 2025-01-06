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
    var body: some View {
        Form {
            TextField("OpenRouter Key", text: $openrouterKey)
        }
        .formStyle(.grouped)
    }
}
