import Foundation
import Combine

extension Document: AgentThreadStore {
    func readThreadModel() async -> ThreadModel {
        await store.readAsync().thread
    }

    func modifyThreadModel<ReturnVal>(_ callback: @escaping (inout ThreadModel) -> ReturnVal) async -> ReturnVal {
        await store.modifyAsync { state in
            return callback(&state.thread)
        }
    }

    func threadModelPublisher() -> AnyPublisher<ThreadModel, Never> {
        store.publisher.map(\.thread).eraseToAnyPublisher()
    }
}

extension Document {
    func pause() {
        store.modify { state in
            if state.thread.status == .running {
                state.thread.status = .paused
            }
        }
    }

    func unpause() {
        store.modify { state in
            if state.thread.status == .paused {
                state.thread.status = .running // causes checkCancelOrPause to finish
            }
        }
    }

    func stop() {
        // Cancel the current agent task
        currentAgentTask?.cancel()
        currentAgentTask = nil
        toolModalToPresent = nil

        // Reset typing state
        store.modify { state in
            state.thread.status = .none
            state.thread.cancelCount += 1
        }
    }
}
