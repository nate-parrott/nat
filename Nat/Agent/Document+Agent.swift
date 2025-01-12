import Foundation

extension Document: AgentThreadStore {
    func readThreadModel() async -> ThreadModel {
        await store.readAsync().thread
    }

    func modifyThreadModel<ReturnVal>(_ callback: @escaping (inout ThreadModel) -> ReturnVal) async -> ReturnVal {
        await store.modifyAsync { state in
            return callback(&state.thread)
        }
    }
}
