import SwiftUI

struct ProgressBadge: View {
    let comparison: ProgressComparison

    private var symbol: String {
        switch comparison.status {
        case .progressed: return "arrow.up.right.circle.fill"
        case .matched: return "equal.circle.fill"
        case .regressed: return "arrow.down.right.circle.fill"
        case .baseline: return "flag.circle"
        case .pending: return "clock"
        case .notLogged: return "minus.circle"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(comparison.status.rawValue, systemImage: symbol)
                .font(.headline).foregroundStyle(.primary)
            Text(comparison.reason).font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
}
