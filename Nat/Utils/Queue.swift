import Foundation

public struct Queue {
    public let id: String
    public let queue: DispatchQueue

    public static func create(label: String = "Unnamed Queue", qos: DispatchQoS = .userInitiated) -> Queue {
        let uuid = UUID().uuidString
        let id = "\(label):\(uuid)"
        return Queue(id: id, queue: DispatchQueue(label: id, qos: qos, attributes: [], autoreleaseFrequency: .inherit, target: nil))
    }

    public static let main = Queue(id: "main", queue: DispatchQueue.main)
    public static let genericUserInitiated = create(label: "GenericUserInitiated")

    public var isCurrent: Bool {
        if id == "main" {
            return Thread.isMainThread
        }
        return DispatchQueue.currentQueueName() == id
    }

    public func assertCurrent() {
        assert(isCurrent)
    }

    public func run(_ block: @escaping () -> ()) {
        if isCurrent {
            block()
        } else {
            queue.async {
                block()
            }
        }
    }

    public func runSync(_ block: () -> ()) {
        if isCurrent {
            block()
        } else {
            if Queue.main.isCurrent {
                print("😤 Synchronous queue hop from main thread!")
            }
            queue.sync {
                block()
            }
        }
    }
}

extension DispatchQueue {
    static func currentQueueName() -> String? {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8)
    }
}
