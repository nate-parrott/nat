import Foundation
import Combine

protocol AgentThreadStore {
    func readThreadModel() async -> ThreadModel
    func modifyThreadModel<ReturnVal>(_ callback: @escaping (inout ThreadModel) -> ReturnVal) async -> ReturnVal
    func threadModelPublisher() -> AnyPublisher<ThreadModel, Never>
}

extension AgentThreadStore {
    func checkCancelOrPause() async throws {
        try Task.checkCancellation()

        for await value in threadModelPublisher().removeDuplicates().values {
            try Task.checkCancellation()
            if case .paused = value.status {
                continue
            } else {
                return
            }
        }
    }
}
