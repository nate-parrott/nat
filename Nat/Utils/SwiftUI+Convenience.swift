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

struct ForEachUnidentifiableWithIndices<Element, Content: View>: View {
    var items: [Element]
    @ViewBuilder var content: (Int, Element) -> Content

    var body: some View {
        ForEach(itemsAsIdentifiable) {
            content($0.id, $0.element)
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

extension Animation {
    static func niceDefault(duration: TimeInterval) -> Animation {
        .timingCurve(0.25, 0.1, 0.25, 1, duration: duration)
    }
    static var niceDefault: Animation { .niceDefault(duration: 0.3) }
}


private struct ContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

extension View {
    func measureSize(_ callback: @escaping (CGSize) -> Void) -> some View {
        background(GeometryReader(content: { geo in
            Color.clear
                .preference(key: ContentSizePreferenceKey.self, value: geo.size)
        }))
        .onPreferenceChange(ContentSizePreferenceKey.self) { size in
            callback(size)
        }
    }
}

private struct ContentFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {}
}

extension View {
    func measureFrame(coordinateSpace: CoordinateSpace, _ callback: @escaping (CGRect) -> Void) -> some View {
        background(GeometryReader(content: { geo in
            Color.clear
                .preference(key: ContentFramePreferenceKey.self, value: geo.frame(in: coordinateSpace))
        }))
        .onPreferenceChange(ContentFramePreferenceKey.self) { frame in
            callback(frame)
        }
    }
}


extension Text {
    init(markdown: String) {
        self = .init(LocalizedStringKey(markdown))
    }
}

