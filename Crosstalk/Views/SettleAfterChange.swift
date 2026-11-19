import SwiftUI

/// Ignores taps while the screen changes.
///
/// Buttons on consecutive screens line up: Echo got it sits where "No one"
/// appears, a winner button where "Play again" appears, Start Game over the
/// name list.
/// Without this, the second tap of a quick double tap lands on the next
/// screen and makes a choice nobody meant. The pause lasts exactly as long
/// as the push animation, so it ends when the new screen comes to rest.
private struct SettleAfterChange<Value: Equatable>: ViewModifier {
    let value: Value
    let settleTime: TimeInterval
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
        DispatchQueue.main.asyncAfter(deadline: .now() + settleTime) {
            // A newer change restarted the wait; let that one unlock.
            if current == generation { isSettling = false }
        }
    }
}

extension View {
    /// Ignores taps briefly when the view appears and whenever `value` changes.
    /// The default pause matches the screen push.
    func settlesAfterChange<Value: Equatable>(
        of value: Value,
        for settleTime: TimeInterval = Style.transitionDuration
    ) -> some View {
        modifier(SettleAfterChange(value: value, settleTime: settleTime))
    }
}
