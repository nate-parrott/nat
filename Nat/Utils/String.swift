import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func truncateHeadWithEllipsis(chars: Int) -> String {
        // Written by Phil
        guard count > chars else { return self }
        let startIndex = index(endIndex, offsetBy: -chars)
        return "..." + self[startIndex...]
    }
}
