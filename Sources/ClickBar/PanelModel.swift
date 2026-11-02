import Foundation
import Observation

@MainActor
@Observable
final class PanelModel {
    var tab: PanelTab = .today
    var historyRange: HistoryRange = .week
    var selectedKey: String?
    var hoveredKey: String?
    var hoveredHour: Int?
    var confirmReset = false
}
