import SwiftUI

enum AppKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Attach inside each navigation destination, including sheets, so numeric pads also get Done.
    func dismissibleKeyboard() -> some View {
        self.scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово", action: AppKeyboard.dismiss)
                        .accessibilityIdentifier("dismissKeyboard")
                }
            }
    }
}
