import SwiftUI

struct ExpandingScrollView<C: View>: View {
    var maxHeight: CGFloat
    @ViewBuilder var view: () -> C

    @State private var contentHeight: CGFloat?

    var body: some View {
        ScrollView {
            VStack {
                view()
            }
            .measureSize({ self.contentHeight = $0.height })
        }
        .frame(height: min(contentHeight ?? 100, maxHeight))
    }
}
