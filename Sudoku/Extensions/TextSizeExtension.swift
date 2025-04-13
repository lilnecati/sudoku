import SwiftUI

extension TextSizePreference {
    func toDynamicTypeSize() -> DynamicTypeSize {
        switch self {
        case .small:
            return .xSmall
        case .medium:
            return .large
        case .large:
            return .xLarge
        }
    }
} 