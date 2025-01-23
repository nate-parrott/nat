import Foundation
import ChatToys

// FakeFunctions let us use an XML syntax to approximate function calling.
// When it's on, we create a system prompt that explains what function calling is -- how to use the xml syntax, and to finish your message and wait for a response.
// Function call syntax looks like this:
// <function>my_tool_name({"json_arg": 1, "another_arg": "hey!"})</function>
// And there can be multiple per response
enum FakeFunctions {
    static func toolsToSystemPrompt(_ fns: [LLMFunction]) -> String {
        let fnDescriptions = fns.map { fn in 
            """
            \(fn.name): \(fn.description)
            Parameters: \(fn.parameters)
            """
        }.joined(separator: "\n\n")
        
        return """
        In this environment you have access to a set of tools to help you complete tasks. 
        You don't need to use a tool, but you can if you want.
        
        To use these tools, write function calls using XML syntax like this:
        <function>tool_name({"arg1": "value1", "arg2": 42})</function>
        
        You can make multiple function calls in a single response, and you can mix function calls with text responses. After making function calls, wait for the user response before proceeding.
        
        Available tools:
        \(fnDescriptions)
        """
    }

    static func parseFakeFunctionsFromResponse(_ response: String) -> (String, [LLMMessage.FunctionCall]) {
        // Split on <function> tags and process each part
        let parts = response.components(separatedBy: "<function>")
        var cleanedResponse = parts[0] // First part is always text before any function calls
        var functionCalls: [LLMMessage.FunctionCall] = []
        
        // Process each part after splitting (skip first since it's pre-function text)
        for part in parts.dropFirst() {
            // Split on closing tag
            let subParts = part.components(separatedBy: "</function>")
            guard subParts.count >= 2 else { continue }
            
            // Extract function content and remaining text
            let functionContent = subParts[0]
            cleanedResponse += subParts[1] // Add text after function call back to response
            
            // Parse function name and arguments
            // Expected format: function_name({"arg": "value"})
            guard let openParenIndex = functionContent.firstIndex(of: "(") else { continue }

            let name = String(functionContent[..<openParenIndex]).trimmingCharacters(in: .whitespaces)
            let arguments = String(functionContent[functionContent.index(after: openParenIndex)...].dropLast()) // last paren

            functionCalls.append(LLMMessage.FunctionCall(name: name, arguments: arguments))
        }
        
        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), functionCalls)
    }
}

extension LLMMessage {
    var byConvertingFakeFunctionCallsToRealOnes: LLMMessage {
        var converted = self
        let (text, calls) = FakeFunctions.parseFakeFunctionsFromResponse(content)
        if calls.count > 0 {
            converted.content = text
            converted.functionCalls = calls
        }
        return converted
    }

    var byConvertingFunctionsToFakeFunctions: LLMMessage {
        var converted = self
        for call in functionCalls {
            converted.content += "\n\(call.asFakeFnStringXML)"
        }
        converted.functionCalls = []
        if role == .function {
            converted.role = .user
            converted.functionResponses = []
            var lines = [String]()
            for resp in functionResponses {
                lines.append("<function-response name='\(resp.functionName)'>")
                lines.append(resp.text)
                lines.append("</function-response>")
            }
            converted.content = lines.joined(separator: "\n")
        }
        return converted
    }
}

extension LLMMessage.FunctionCall {
    var asFakeFnStringXML: String {
        return "<function>\(name)(\(arguments))</function>"
    }
}
