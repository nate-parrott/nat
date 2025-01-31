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

        // If cancelCount changes we must stop immediately (even though we should also get a cancellation call)
        var lastCancelCount: Int?
        for await value in threadModelPublisher().removeDuplicates().values {
            if value.status != .paused {
                return // escape
            }
            try Task.checkCancellation()
            if let lastCancelCount, value.cancelCount != lastCancelCount {
                throw CancellationError()
            }
            lastCancelCount = value.cancelCount
        }
    }
}
