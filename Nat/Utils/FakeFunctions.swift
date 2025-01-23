import Foundation
import ChatToys

/*
 public struct LLMFunction: Equatable, Encodable {
     public var name: String
     public var description: String
     public var parameters: JsonSchema
     public var strict: Bool?

     public init(name: String, description: String, parameters: [String: JsonSchema], required: [String]? = nil, strict: Bool? = nil) {
         self.name = name
         self.description = description
         self.parameters = .object(description: nil, properties: parameters, required: required ?? Array(parameters.keys))
         self.strict = strict
     }

     public indirect enum JsonSchema: Equatable, Encodable {
         case string(description: String?) // Encode as type=string, description=description
         case number(description: String?) // Encode as type=number, description=description
         case boolean(description: String?) // Encode as type=boolean, description=description
         case enumerated(description: String?, options: [String]) // Encode as type=string, enum=options, description=description
         case object(description: String?, properties: [String: JsonSchema], required: [String]) // Encode as type=object, properties=properties, required=required
         case array(description: String?, itemType: JsonSchema) // Encode as type=array, items=itemType
 */

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
        In this environment you have access to a set of tools to help you complete tasks. To use these tools, write function calls using XML syntax like this:
        <function>tool_name({"arg1": "value1", "arg2": 42})</function>
        
        You can make multiple function calls in a single response. After making function calls, wait for the response before proceeding.
        
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

//public struct LLMMessage.FunctionCall: Equatable, Codable, Hashable {
//    public var id: String?
//    public var name: String
//    public var arguments: String // as json string
