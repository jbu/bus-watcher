import SwiftUI

enum StopColor: String, Codable, CaseIterable, Sendable {
    case blue, green, orange, purple, red, teal, indigo, pink, gray

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .green:  return .green
        case .orange: return .orange
        case .purple: return .purple
        case .red:    return .red
        case .teal:   return .teal
        case .indigo: return .indigo
        case .pink:   return .pink
        case .gray:   return .gray
        }
    }
}
