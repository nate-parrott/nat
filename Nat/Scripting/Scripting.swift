import Foundation

#if os(macOS)
import AppKit

enum Scripting {
    enum ScriptError: Error {
        case scriptError([String: AnyObject])
        case invalidScript
    }

    private static let scriptQueue = DispatchQueue(label: "Scripting", qos: .userInitiated, attributes: .concurrent)

    static func runAppleScriptAndGetString(script: String) async throws -> String? {
        try await runAppleScript(script: script, extract: \.asString)
    }

    static func runAppleScript<T>(script: String, extract: @escaping (NSAppleEventDescriptor) -> T) async throws -> T {
        print("[Applescript] \(script)")
        return try await withCheckedThrowingContinuation { cont in
            self.scriptQueue.async {
                var error: NSDictionary?
                guard let scriptObject = NSAppleScript(source: script) else {
                    cont.resume(throwing: ScriptError.invalidScript)
                    return
                }
                let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error)
                if let error {
                    cont.resume(throwing: ScriptError.scriptError(error as? [String: AnyObject] ?? [:]))
                    return
                }
                cont.resume(returning: extract(output))
            }
        }
    }

    static func safariTitle() async throws -> String? {
        try await runAppleScriptAndGetString(script: """
        tell application "Safari"
            return title of active tab of window 1
        end tell
        """)
    }

    static func xcodeState() async throws -> (project: URL?, file: URL?) {
        let items = try await runAppleScript(script: """
        tell application "Xcode"
            -- Get workspace path
            set workspacePath to "?"
            set currentDocument to missing value
            
            set currentWorkspace to active workspace document
            if currentWorkspace is not missing value then
                try
                    set workspacePath to POSIX path of (file of currentWorkspace as text)
                end try
            end if
            
            -- Try to get first source document by checking the window name and looking for the last matching source doc with that name. Such a fucking hack lmao
            try
                set lastWord to (word -1 of (get name of window 1))
                set currentDocument to last source document whose name ends with lastWord
                -- log properties of currentDocument
            end try
            
            -- Get current file path
            set currentPath to "?"
            if currentDocument is not missing value then
                try
                    set currentPath to path of currentDocument
                end try
            end if
            
            -- set currentPath to name of last source document
            
            return {workspacePath, currentPath}
        end tell
        """, extract: \.asArrayOfStrings)
        guard let items, items.count == 2 else {
            return (nil, nil)
        }
        func parsePart(id: Int) -> URL? {
            let str = items[id]
            if str == "?" { return nil }
            return URL(fileURLWithPath: str)
        }
        return (
            parsePart(id: 0),
            parsePart(id: 1)
        )
    }
}

extension NSAppleEventDescriptor {
    var asArrayOfStrings: [String]? {
        // Written by Phil
        var result: [String] = []
        for i in 1...numberOfItems {
            if let item = self.atIndex(i)?.asString {
                result.append(item)
            }
        }
        return result.isEmpty ? nil : result
    }

    var asString: String? {
        switch descriptorType {
        case typeUnicodeText, typeUTF8Text:
            return stringValue
        case typeSInt32:
            return String(int32Value)
        case typeTrue: return "true"
        case typeFalse: return "false"
        case typeBoolean:
            return String(booleanValue)
        case typeAEList:
            let listCount = numberOfItems
            var listItems: [String] = []
            if listCount > 0 {
                for i in 1...listCount { // AppleScript lists are 1-indexed
                    if let itemString = self.atIndex(i)?.asString {
                        listItems.append(itemString)
                    }
                }
                return listItems.joined(separator: ", ")
            } else {
                return "(empty list)"
            }
        case typeAERecord:
            // Assuming you want key-value pairs for records
            var recordItems: [String] = []
            for i in 1...numberOfItems {
                let key = self.atIndex(i)?.stringValue ?? "UnknownKey"
                let value = self.atIndex(i + 1)?.asString ?? "UnknownValue"
                recordItems.append("\(key): \(value)")
            }
            return recordItems.joined(separator: ", ")
        default:
            return nil // Handle other descriptor types as needed
        }
    }
}

#endif

extension String {
    var quotedForApplescript: String {
        // TODO: DO better
        let esc = replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(esc)\""
//        jsonString // is this correct??
    }
}
