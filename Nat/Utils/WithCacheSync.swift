import SwiftUI

/// A SwiftUI utility that caches the last input/output pair and only recomputes when input changes
struct WithCacheSync<Input: Equatable, Output, V: View>: View {
    private class Cache: ObservableObject {
        @Published var lastInput: Input?
        @Published var lastOutput: Output?
    }
    
    let input: Input
    let compute: (Input) -> Output
    @ViewBuilder let view: (Output) -> V
    @StateObject private var cache = Cache()
    
    var body: some View {
        if let output = cache.lastOutput, cache.lastInput == input {
            // Use cached value if input hasn't changed
            view(output)
        } else {
            // Compute and cache new value if input changed
            view(computeAndCache())
        }
    }
    
    private func computeAndCache() -> Output {
        let output = compute(input)
        cache.lastInput = input
        cache.lastOutput = output
        return output
    }
}
