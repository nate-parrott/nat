import SwiftUI

extension View {
    var asAny: AnyView { AnyView(self) }

    func frame(both: CGFloat, alignment: Alignment = .center) -> some View {
        self.frame(width: both, height: both, alignment: alignment)
    }
}

extension String {
    var asText: Text {
        Text(self)
    }
}

struct IdentifiableWithIndex<Item: Identifiable>: Identifiable {
    let id: Item.ID
    let item: Item
    let index: Int
}

extension Array where Element: Identifiable {
    var identifiableWithIndices: [IdentifiableWithIndex<Element>] {
        return enumerated().map { tuple in
            let (index, item) = tuple
            return IdentifiableWithIndex(id: item.id, item: item, index: index)
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .displayP3,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct ForEachUnidentifiable<Element, Content: View>: View {
    var items: [Element]
    @ViewBuilder var content: (Element) -> Content

    var body: some View {
        ForEach(itemsAsIdentifiable) {
            content($0.element)
        }
    }

    private var itemsAsIdentifiable: [CustomIdentifiable<Element>] {
        items.enumerated().map { CustomIdentifiable(id: $0.offset, element: $0.element) }
    }
}

private struct CustomIdentifiable<Element>: Identifiable {
    var id: Int
    var element: Element
}

// A @StateObject that remembers its first initial value
class FrozenInitialValue<T>: ObservableObject {
    private var value: T?
    func readOriginalOrStore(initial: () -> T) -> T {
        let val = value ?? initial()
        self.value = val
        return val
    }
}

extension View {
    func onAppearOrChange<E: Equatable>(of val: E, perform: @escaping (E) -> Void) -> some View {
        self.onChange(of: val, perform: perform).onAppear(perform: { perform(val) })
    }
}
