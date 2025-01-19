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

    func truncateTailWithEllipsis(chars: Int) -> String {
        // Written by Phil
        guard count > chars else { return self }
        let endIndex = index(startIndex, offsetBy: chars)
        return self[..<endIndex] + "..."
    }

    var lines: [String] {
        components(separatedBy: "\n")
    }

    // i dont give a shit about knowing the encoding sorry
    init(fromURL url: URL) throws {
        var enc = String.Encoding.utf8
        self = try String(contentsOf: url, usedEncoding: &enc)
    }
}

