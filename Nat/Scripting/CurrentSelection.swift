//import ApplicationServices
//import Cocoa
//
//func getSelectedText() -> String? {
//    let systemWideElement = AXUIElementCreateSystemWide()
//
//    var selectedTextValue: AnyObject?
//    let errorCode = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &selectedTextValue)
//    
//    if errorCode == .success {
//        let selectedTextElement = selectedTextValue as! AXUIElement
//        var selectedText: AnyObject?
//        let textErrorCode = AXUIElementCopyAttributeValue(selectedTextElement, kAXSelectedTextAttribute as CFString, &selectedText)
//        
//        if textErrorCode == .success, let selectedTextString = selectedText as? String {
//            return selectedTextString
//        } else {
//            return nil
//        }
//    } else {
//        return nil
//    }
//}
