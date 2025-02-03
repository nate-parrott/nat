import Foundation

extension FileEdit {
    /// Checks syntax for Swift files and returns error message if any
    func checkSyntax() async -> String? {
        // Only check Swift files
        guard path.pathExtension == "swift" else { return nil }
        
        do {
            // Get the complete content after applying edits
            let (_, after) = try getBeforeAfter()
            
            // Run syntax check
            let result = await checkSwiftSyntax(code: after)
            switch result {
            case .ok:
                return nil
            case .failed(let error):
                return "⚠️ Syntax check failed for \(path):\n\(error)"
            }
        } catch {
            return "Failed to check syntax: \(error.localizedDescription)"
        }
    }
}
