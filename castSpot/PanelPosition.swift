import Foundation

enum PanelPosition: String, CaseIterable {
    case topCenter    = "topCenter"
    case topLeft      = "topLeft"
    case topRight     = "topRight"
    case screenCenter = "screenCenter"

    static let defaultsKey = "panelPosition"

    static var current: PanelPosition {
        PanelPosition(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .topCenter
    }

    var label: String {
        switch self {
        case .topCenter:    return "Top Center"
        case .topLeft:      return "Top Left"
        case .topRight:     return "Top Right"
        case .screenCenter: return "Screen Center"
        }
    }
}
