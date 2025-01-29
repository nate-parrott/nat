import SwiftUI

extension URL {
    // Returns this url, or an ancestor, that contains a git directory
    func ancestorGitDir() -> URL? {
        // Check for .git dir here, then recur
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path(percentEncoded: false), isDirectory: &isDir)
        if isDir.boolValue {
            return self._ancestorGitDir
        } else {
            return self.deletingLastPathComponent()._ancestorGitDir
        }
    }

    private var _ancestorGitDir: URL? {
        let gitDir = appending(component: ".git", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: gitDir.path(percentEncoded: false)) {
            return self
        }
        if pathComponents.count > 1 {
            return deletingLastPathComponent()._ancestorGitDir
        }
        return nil
    }
}
