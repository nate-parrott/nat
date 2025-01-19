import Foundation

extension Collection {
    var asArray: [Element] {
        Array(self)
    }

    func grouped<K: Hashable>(_ key: (Element) -> K) -> [K: [Element]] {
        var dict = [K: [Element]]()
        for item in self {
            dict[key(item), default: []].append(item)
        }
        return dict
    }
}
