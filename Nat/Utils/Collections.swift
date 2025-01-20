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

extension Array {
    func grouped(arraySize: Int) -> [[Element]] {
        var groups = [[Element]]()
        for item in self {
            if groups.count == 0 || groups.last!.count >= arraySize {
                groups.append([item])
            } else {
                groups[groups.count - 1].append(item)
            }
        }
        return groups
    }
}

