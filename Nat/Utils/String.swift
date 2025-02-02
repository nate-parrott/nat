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
    
    func truncateMiddleWithEllipsis(chars: Int) -> String {
        guard count > chars else { return self }
        let cut = chars / 2
        let prefix = self[..<index(startIndex, offsetBy: cut)]
        let suffix = self[index(endIndex, offsetBy: -cut)...]
        return prefix + "..." + suffix
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


extension URL {
    // If self is /abc/def/ghi and base is /abc, then returns def/ghi
    // TODO: Should we do ../ etc?
    func asPathRelativeTo(base: URL) -> String? {
        var baseStr = base.standardizedFileURL.absoluteString
        if !baseStr.hasSuffix("/") {
            baseStr += "/"
        }
        let selfStr = standardizedFileURL.absoluteString
        if selfStr.hasPrefix(baseStr) {
            let relativePath = selfStr.dropFirst(baseStr.count)
            return String(relativePath)
        } else {
            return nil
        }
    }
}
