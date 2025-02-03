import SwiftUI

// From https://www.fivestars.blog/articles/reverse-masks-how-to/

extension View {
  @ViewBuilder public func reverseMask<Mask: View>(
    alignment: Alignment = .center,
    cornerRadius: CGFloat = 0,
    @ViewBuilder _ mask: () -> Mask
  ) -> some View {
      self.mask {
          Group {
              if cornerRadius == 0 {
                  Rectangle()
              } else {
                  RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              }
          }
          .overlay(alignment: alignment) {
            mask()
              .blendMode(.destinationOut)
          }
      }

  }
}
