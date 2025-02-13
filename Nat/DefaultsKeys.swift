import Foundation

enum DefaultsKeys: String {
    case openrouterKey
    case openAIKey
    case pollRemotelyTriggeredTasks // bool
    case hasSeenRemindersExplanation // bool
}

extension DefaultsKeys {
    func boolValue(defaultValue def: Bool = false) -> Bool {
        return UserDefaults.standard.bool(forKey: rawValue)
    }

    func stringValue(defaultValue def: String = "") -> String {
        return UserDefaults.standard.string(forKey: rawValue) ?? def
    }
}
