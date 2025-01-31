import AppKit

extension NSButton {
    func setTitleAndGlyph(_ title: String, glyph: String) {
        // Written by Phil
        let attachment = NSTextAttachment()
        attachment.image = NSImage(systemSymbolName: glyph, accessibilityDescription: nil)
        let attributedGlyph = NSAttributedString(attachment: attachment)
        let attributedTitle = NSAttributedString(string: " " + title)
        let str = attributedGlyph.mutableCopy() as! NSMutableAttributedString
        str.append(attributedTitle)
        self.attributedTitle = str
    }
}
