import Foundation
import Combine

#if os(OSX)
      import AppKit
  #elseif os(iOS)
      import UIKit
  #endif

// TODO: Save on deinit, not just app close? (for non-globals)
open class DataStore<Model: Equatable & Codable>: NSObject {
    public typealias ChangeHook = (Model, inout Model) -> Void

    private var _model: Model {
        didSet {
            if _model != oldValue {
                subject.send(_model)
            }
        }
    }
    private var subject: CurrentValueSubject<Model, Never>

    public let persistenceKey: String?
    public let queue: Queue

    public var model: Model {
        get {
            var val: Model!
            queue.runSync {
                val = self._model
            }
            return val
        }
        set(newVal) {
            queue.runSync {
                var modifiedNewVal = newVal
                let oldVal = self._model
                for hook in changeHooks {
                    hook(oldVal, &modifiedNewVal)
                }
                if modifiedNewVal != self._model {
                    self._model = modifiedNewVal
                }
            }
        }
    }

    public var publisher: AnyPublisher<Model, Never> { subject.eraseToAnyPublisher() }

//    private let _observableWithMetadata: MutableObservable<(Model, TransactionMetadata)>
//    public var observableWithMetadata: Observable<(Model, TransactionMetadata)> { return _observableWithMetadata }
//    private let observer = Observer()
    private var changeHooks = [ChangeHook]()

    public init(persistenceKey: String?, defaultModel: Model, queue: Queue) {
        _model = defaultModel
        self.queue = queue
        self.persistenceKey = persistenceKey
//        self._observableWithMetadata = MutableObservable(current: (defaultModel, TransactionMetadata(sender: nil)), queue: queue)
//        self.observable = self._observableWithMetadata.map({ $0.0 })
//        self.uiObservable = self.observable.onQueue(.main).throttledToDisplayRefreshRate
        self.subject = .init(defaultModel)
        super.init()

        // Platform-specific notifications:
        #if os(OSX)
        let willResignActive = NSApplication.willResignActiveNotification
        let willTerminate = NSApplication.willTerminateNotification
        #elseif os(iOS)
            let willResignActive = UIApplication.willResignActiveNotification
            let willTerminate = UIApplication.willTerminateNotification
        #endif

        let startTime = CACurrentMediaTime()

        queue.run {
            var loadedBytes: Int = 0

            let initialState: Model? = {
                for url in [self.persistentURL, self.localPathForInitialState].compactMap({ $0 }) {
                    do {
                        let data = try Data(contentsOf: url)
                        loadedBytes += data.count
                        guard var state = (try? self.decode(data: data)) ?? self.migrate(previousData: data) else {
                            throw DataStoreErrors.couldNotDecodeModel
                        }
                        print("Loaded \(url)")
                        self.processModelAfterLoad(model: &state)
                        return state
                    } catch {
                        let name = self.persistenceKey ?? "<unknown>"
                        print("Failed to load \(name) datastore: \(error)")
                    }
                }
                return nil
            }()

            if let state = initialState {
                self._model = state
            }
            NotificationCenter.default.addObserver(self, selector: #selector(self.save), name: willResignActive, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.saveSync), name: willTerminate, object: nil)

//            self.observer.observe(self.observable) { [weak self] value in
//                self?.subject.value = value
//            }

            self.setup()

            let loadTime = CACurrentMediaTime() - startTime
            self.didCompleteInitialLoad(duration: loadTime, bytesRead: loadedBytes)
        }
    }

    func loadFromData(_ data: Data) throws {
        // Populates this store with data read from disk (e.g. from Document)
        guard var state = (try? self.decode(data: data)) ?? self.migrate(previousData: data) else {
            throw DataStoreErrors.couldNotDecodeModel
        }
        self.processModelAfterLoad(model: &state)
        self.model = state
    }

    // Override to provide custom encode/decode
    open func decode(data: Data) throws -> Model {
        try JSONDecoder().decode(Model.self, from: data)
    }

    open func encode(model: Model) throws -> Data {
        try JSONEncoder().encode(model)
    }

    open func setup() {
        // for subclasses
    }

    public func modify(_ block: @escaping (inout Model) -> ()) {
        queue.run {
            var newModel = self.model
            block(&newModel)
            self.model = newModel
        }
    }

    @objc public func save() {
        queue.run {
            self.cleanup(model: &self._model)
            if let key = self.persistenceKey {
                var processed = self._model
                self.processModelBeforePersist(model: &processed)
                try! (try! self.encode(model: processed)).write(to: DataStore.persistentURL(key))
            }
        }
    }

    @objc func saveSync() {
        queue.runSync {
            self.save()
        }
    }

    public var persistentURL: URL? {
        if let key = self.persistenceKey {
            return Self.persistentURL(key)
        }
        return nil
    }

    static func persistentURL(_ key: String) -> URL {
        let appDir = "DataStores"
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent(appDir)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir.appendingPathComponent(key + ".json")
    }

    public func addChangeHook(_ changeHook: @escaping ChangeHook) {
        changeHooks.append(changeHook)
    }

    /// override this method to provide 'cleanup logic' to ensure that this data structure does not grow to an unbounded size.
    open func cleanup(model: inout Model) {
    }

    open func processModelBeforePersist(model: inout Model) {
    }

    open func processModelAfterLoad(model: inout Model) {
    }

    open func didCompleteInitialLoad(duration: TimeInterval, bytesRead: Int) {
        // override to do metrics
    }

    open var localPathForInitialState: URL? {
        return nil
    }

    open func migrate(previousData data: Data) -> Model? {
        return nil
    }

    // MARK: - Concurrency

    public func readAsync() async -> Model {
        return await withCheckedContinuation { continuation in
            self.queue.run {
                continuation.resume(returning: self.model)
            }
        }
    }

    @discardableResult
    public func modifyAsync<T>(_ block: @escaping (inout Model) -> T) async -> T {
        return await withCheckedContinuation({ cont in
            self.queue.run {
                self.modify { state in
                    let result = block(&state)
                    cont.resume(returning: result)
                }
            }
        })
    }
}

private enum DataStoreErrors: Error {
    case couldNotDecodeModel
}
