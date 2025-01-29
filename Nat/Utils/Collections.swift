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

    func ranges(subArray: [Element]) -> [NSRange] where Element: Equatable {
        // Written by Phil
        var result = [NSRange]()
        let subArrayCount = subArray.count
        guard subArrayCount > 0 else { return result }
        
        for index in 0...(self.count - subArrayCount) {
            let range = self[index..<(index + subArrayCount)]
            if Array(range) == subArray {
                result.append(NSRange(location: index, length: subArrayCount))
            }
        }
        return result
    }
}

// Written by Phil
extension Array where Element: Numeric {
    func sum() -> Element {
        return reduce(0, +)
    }
}
