import SwiftUI
import UIKit

extension View {
    func hideKeyboardWhenTappedOutside() -> some View {
        return self.onTapGesture(perform: {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        })
    }
} 