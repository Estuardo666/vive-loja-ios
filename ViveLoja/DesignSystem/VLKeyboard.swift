import SwiftUI
import UIKit

extension View {
    /// Dismisses the keyboard when the user taps somewhere that did not consume
    /// the touch.
    ///
    /// `simultaneousGesture` rather than `onTapGesture`: the latter would sit in
    /// front of every button and text field underneath and swallow their taps.
    /// This runs alongside them, so controls keep working and a tap on empty
    /// space still closes the keyboard.
    func vlDismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
