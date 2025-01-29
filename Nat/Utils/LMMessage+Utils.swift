import ChatToys

extension LLMMessage {
    var approxCharCount: Int {
        var i = 4 // role, approx
        i += content.count
        for resp in functionResponses {
            i += resp.text.count + 4 // metadata
        }
        for call in functionCalls {
            i += call.name.count + 4 + call.arguments.count
        }
        return i
    }
}
