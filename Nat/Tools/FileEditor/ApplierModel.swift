import Foundation
import ChatToys

extension FileEdit {
    var canBeAppliedUsingApplierModel: Bool {
        if edits.isEmpty { return false }
        for edit in edits {
            switch edit {
            case .write: return false
            case .replace, .findReplace, .append: return true
            }
        }
        return false
    }

    func applyUsingLLM(comments: String) async throws -> String {
        // TODO: Use comments
        let content = try String(contentsOf: path)
        let editDescriptions: [String] = edits.compactMap { edit -> String? in
            switch edit {
            case .replace(_, let lineRangeStart, let lineRangeLen, let lines):
                return """
                ```
                > FindReplace Lines \(lineRangeStart) + \(lineRangeStart + lineRangeLen - 1) with:
                \(lines.joined(separator: "\n"))
                ```
                """
            case .write: return nil
            case .append(_, let content):
                return """
                ```
                > Add to file near end:
                \(content)
                ```
                """
            case .findReplace(_, let find, let replace):
                return """
                ```
                > FindReplace these lines:
                \(find.joined(separator: "\n"))
                ==WITH==
                \(replace.joined(separator: "\n"))
                ```
                """
            }
        }
        let prompt = """
        Your job is to apply a code edit written by an expert coder.
        I'll give you the current file and a list of edits.
        Edits may take the form of 'append' operations,
        'find and replace' operations or 'replace line range' operations.
        It's your job to output the entire final file, within code blocks, with all edits applied.
        (``` ONLY)
        The edit instructions may contain minor mistakes about WHERE to insert the file or exactly what text to REPLACE; your job is to output the syntactically valid, reasonable version WITHOUT changing the code that the edits add. 
        Do not take liberties or fix the code yourself besides inserting the code in the reasonable place.
        It is your job to write the WHOLE new file so it can be written to disk. Never omit.
        
        For example, you might have a file like this:
        ```
        def hello():
            if hour < 12:
                return 'good morning'
            else:
                return 'good afternoon'
        ```
        And an edit like this:
        ```
        > FindReplace
            else:
        ==WITH==
            elif hour > 5:
                return 'good evening'
            else:
        ```
        
        You would output:
        ```
        def hello():
            if hour < 12:
                return 'good morning'
            elif hour > 5:
                return 'good evening'
            else:
                return 'good afternoon'
        ```
        
        Now, here is the file:
        [BEGIN FILE]
        \(content)
        [END FILE]
        
        And here are the edits:
        \(editDescriptions)
        """
        let makesSenseToUsePredictedOutput = content.count > editDescriptions.joined(separator: "\n").count * 2
        print("<applier-input>\n\(prompt)\n</applier-input>")
        let predictedOutput: String? = makesSenseToUsePredictedOutput ? "```\n\(content)\n```" : nil
        var llm = try LLMs.quickModel()
        llm.prediction = predictedOutput
        let resp = try await llm.complete(prompt: [
            LLMMessage(role: .system, content: prompt)
        ]).content.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
        print("<applier-output>\n\(resp)\n</applier-output>")
        return resp
    }
}
