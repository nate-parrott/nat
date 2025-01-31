import Foundation
import ChatToys
import SwiftUI

class TodoTool: Tool {
    var functions: [LLMFunction] {
        [createTodoFn.asLLMFunction, setTodoStatusFn.asLLMFunction]
    }
    
    let createTodoFn = TypedFunction<CreateTodoArgs>(
        name: "create_todos",
        description: "Create new todos with specified IDs and descriptions",
        type: CreateTodoArgs.self
    )
    
    struct CreateTodoArgs: FunctionArgs {
        struct TodoItem: Codable {
            var id: String
            var description: String
        }
        var todos: [TodoItem]
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "todos":
                        .object(description: nil, properties: ["id": .string(description: "camel_case id"), "description": .string(description: nil)], required: ["id", "description"])
            ]
        }
    }
    
    let setTodoStatusFn = TypedFunction<SetTodoStatusArgs>(
        name: "set_todo_status",
        description: "Set the status of a todo by ID",
        type: SetTodoStatusArgs.self
    )
    
    struct SetTodoStatusArgs: FunctionArgs {
        var id: String
        var status: Todo.Status
        
        static var schema: [String: LLMFunction.JsonSchema] {
            [
                "id": .string(description: "ID of the todo to update"),
                "status": .enumerated(description: nil, options: ["queued", "inProgress", "complete"])
            ]
        }
    }
    
    func handleCallIfApplicable(_ call: LLMMessage.FunctionCall, context: ToolContext) async throws -> TaggedLLMMessage.FunctionResponse? {
        if let args: CreateTodoArgs = createTodoFn.checkMatch(call: call) {
            guard let document = context.document else { return nil }
            for todo in args.todos {
                document.store.model.todos[todo.id] = Todo(id: todo.id, description: todo.description)
                context.log(.info("Created todo: **\(todo.description)**"))
            }
            return call.response(text:  "Created \(args.todos.count) todos")
        }
        
        if let args: SetTodoStatusArgs = setTodoStatusFn.checkMatch(call: call) {
            guard let document = context.document else { return nil }
            guard var todo = document.store.model.todos[args.id] else {
                return call.response(text: "No todo found with ID: \(args.id)")
            }
            todo.status = args.status
            document.store.model.todos[args.id] = todo
            context.log(.info("Updated todo **\(todo.description)** status to \(args.status.rawValue)"))
            return call.response(text: "Updated todo status")
        }
        
        return nil
    }
    
    func contextToInsertAtBeginningOfThread(context: ToolContext) async throws -> String? {
        guard let document = context.document else { return nil }
        let todos = document.store.model.todos
        if todos.isEmpty { return nil }

        var lines = [String]()
        lines.append("# Tasks")
        lines.append("You must track all tasks the user asks you to perform, or that you realize you need to do, using the tasks system. Keep tasks up to date. Always make a new task when you learn you need to do something. Set its status to `inProgress` when you begin working on it. Set it to `complete` when you finish, then move on to the next queued task.")
        lines.append("# Current tasks:")
        for (_, todo) in todos.sorted(by: { $0.key < $1.key }) {
            lines.append("\(todo.id): \(todo.description) — \(todo.status)")
        }
        return lines.joined(separator: "\n")
    }
}
