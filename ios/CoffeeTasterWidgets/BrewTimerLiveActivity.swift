import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CoffeeTasterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        BrewTimerLiveActivity()
    }
}

struct BrewTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BrewTimerAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .padding()
                .activityBackgroundTint(Color.brown.opacity(0.15))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.methodName, systemImage: context.attributes.symbolName)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.title2.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StepView(state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.attributes.symbolName)
            } compactTrailing: {
                Text(context.state.startedAt, style: .timer)
                    .monospacedDigit()
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

private struct LockScreenView: View {
    let attributes: BrewTimerAttributes
    let state: BrewTimerAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(attributes.methodName, systemImage: attributes.symbolName)
                    .font(.headline)
                Spacer()
                if state.isFinished {
                    Text("Done").font(.title2.bold())
                } else {
                    Text(state.startedAt, style: .timer)
                        .font(.title2.monospacedDigit().bold())
                        .multilineTextAlignment(.trailing)
                }
            }
            StepView(state: state)
            Text(attributes.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StepView: View {
    let state: BrewTimerAttributes.ContentState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.stepTitle).font(.subheadline.bold())
                Text(state.stepDetail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let target = state.target {
                Text(target).font(.headline.monospacedDigit())
            }
            if let next = state.nextStepAt, !state.isFinished {
                Text(timerInterval: Date()...max(next, Date()), countsDown: true)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 44)
            }
        }
    }
}
