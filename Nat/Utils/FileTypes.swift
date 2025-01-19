import UniformTypeIdentifiers

func isTextFile(fileExtension: String) -> Bool {
    let isText = _isTextFile(fileExtension: fileExtension)
//    print(".\(fileExtension) is text? \(isText)")
    return isText
}

private func _isTextFile(fileExtension: String) -> Bool {
    // Remove leading dot if present
    let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))

    // Get the UTI for this extension
    guard let uti = UTType(filenameExtension: ext) else {
        return false
    }

    // Check if it conforms to text content
    return uti.conforms(to: .text) ||
           uti.conforms(to: .plainText) ||
           uti.conforms(to: .sourceCode)
}
