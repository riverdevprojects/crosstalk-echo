import SwiftUI

/// Ignores taps for a moment after the screen changes.
///
/// Buttons on consecutive screens line up: Exit sits where "No one" appears,
/// a winner button where "Play again" appears, Start Game over the name list.
/// Without this, the second tap of a quick double tap lands on the next
/// screen and makes a choice nobody meant.
private struct SettleAfterChange<Value: Equatable>: ViewModifier {
    static var settleTime: TimeInterval { 0.5 }

    let value: Value
    @State private var isSettling = false
    @State private var generation = 0

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isSettling)
            .onAppear(perform: settle)
            .onChange(of: value) { _ in settle() }
    }

    private func settle() {
        generation += 1
        let current = generation
        isSettling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleTime) {
            // A newer change restarted the wait; let that one unlock.
            if current == generation { isSettling = false }
        }
    }
}

extension View {
    /// Ignores taps briefly when the view appears and whenever `value` changes.
    func settlesAfterChange<Value: Equatable>(of value: Value) -> some View {
        modifier(SettleAfterChange(value: value))
    }
}
