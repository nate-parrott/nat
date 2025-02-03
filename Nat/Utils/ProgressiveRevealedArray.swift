import SwiftUI

class ProgressiveRevealedArray<Element: Equatable>: ObservableObject {
    @Published var target = [Element]() {
        didSet {
            if target != oldValue {
                updateTarget()
            }
        }
    }
    @Published private(set) var current = [Element]()
    var delay: TimeInterval = 1.5
    
    private var timer: Timer?
    private func updateTarget() {
        timer?.invalidate()
        timer = nil
        
        current = current.sharedPrefix(other: target)
        appendNext()
    }
    
    private func appendNext() {
        if current.count == target.count { return }
        let next = target[current.count]
        current.append(next)
        
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false, block: { [weak self] _ in
            self?.appendNext()
        })
    }
}


extension Array where Element: Equatable {
    func sharedPrefix(other array: [Element]) -> [Element] {
        // Written by Phil
        var prefix = [Element]()
        for (selfElement, otherElement) in zip(self, array) {
            if selfElement == otherElement {
                prefix.append(selfElement)
            } else {
                break
            }
        }
        return prefix
    }
}
