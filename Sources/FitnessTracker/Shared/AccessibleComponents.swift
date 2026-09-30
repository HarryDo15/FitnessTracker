import SwiftUI

/// Reflows labels and values without shrinking Dynamic Type or clipping long values.
struct AccessibleMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(label).fixedSize()
                Spacer(minLength: 16)
                Text(value).font(.title2.bold()).monospacedDigit().fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                Text(value).font(.title2.bold()).monospacedDigit()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

enum AppColors {
    // White stamps need a darker fill than system pink in light mode (contrast > 7:1).
    static let stampFill = Color(red: 0.62, green: 0.06, blue: 0.28)
}

enum SpokenWorkoutValue {
    static func set(weight: Double, unit: WeightUnit, reps: Int) -> String {
        "\(weight.formatted()) \(unit == .kg ? "kilograms" : "pounds"), \(reps) repetitions"
    }
    static func time(_ seconds: Int) -> String {
        "\(seconds / 60) minutes, \(seconds % 60) seconds"
    }
}
