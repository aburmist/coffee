import ActivityKit
import Foundation

/// Shared between the app (which starts and updates the Live Activity)
/// and the widget extension (which draws it on the Lock Screen and Dynamic Island).
struct BrewTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepTitle: String
        var stepDetail: String
        /// Scale reading to aim for during this step, already formatted ("180 g").
        var target: String?
        var startedAt: Date
        /// When the next step starts, for a countdown; nil on the last step.
        var nextStepAt: Date?
        var isFinished: Bool
    }

    var methodName: String
    var symbolName: String
    var summary: String
}
