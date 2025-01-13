import Foundation

protocol AgentThreadStore {
    func readThreadModel() async -> ThreadModel
    func modifyThreadModel<ReturnVal>(_ callback: @escaping (inout ThreadModel) -> ReturnVal) async -> ReturnVal
}
