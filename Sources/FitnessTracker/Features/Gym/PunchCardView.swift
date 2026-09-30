import SwiftUI

struct PunchCardView: View {
    let card: PunchCard
    var stampedVisitIDs: Set<UUID> = []
    var stampTrigger: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var visits: [GymVisit] {
        var seen = Set<String>()
        return card.visits.sorted {
            let left = $0.punchedAt ?? $0.checkedInAt
            let right = $1.punchedAt ?? $1.checkedInAt
            return left == right ? $0.checkedInAt < $1.checkedInAt : left < right
        }.filter {
            seen.insert($0.dayKey ?? GymVisitRules.dayKey(profileID: card.profile?.id ?? $0.id, date: $0.checkedInAt)).inserted
        }
    }

    var body: some View {
        let carriedOver = min(max(0, card.requiredVisits), max(0, card.carriedOverPunches))
        VStack(alignment: .leading, spacing: 20) {
            AccessibleMetricRow(label: "Gym club", value: "\(min(card.progress, card.requiredVisits)) of \(card.requiredVisits) visits")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 100 : 48), spacing: 12)], spacing: 16) {
                ForEach(0..<max(0, card.requiredVisits), id: \.self) { index in
                    let visitIndex = index - carriedOver
                    let filled = index < carriedOver || visits.indices.contains(visitIndex)
                    let stamped = visits.indices.contains(visitIndex) && stampedVisitIDs.contains(visits[visitIndex].id)
                    ZStack {
                        Circle().strokeBorder(.primary.opacity(contrast == .increased ? 0.85 : 0.5), style: StrokeStyle(lineWidth: 2, dash: filled ? [] : [4]))
                        if filled {
                            Circle().fill(AppColors.stampFill)
                            Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(.white)
                        } else { Text("\(index + 1)").font(.headline).foregroundStyle(.secondary) }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .phaseAnimator([false, true, false], trigger: stamped ? stampTrigger : 0) { content, phase in
                        content.scaleEffect(phase && stamped && !reduceMotion ? 1.2 : 1)
                            .rotationEffect(.degrees(phase && stamped && !reduceMotion ? -10 : 0))
                    } animation: { _ in .spring(response: 0.3, dampingFraction: 0.5) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Punch \(index + 1) of \(card.requiredVisits), \(index < carriedOver ? "previously earned" : filled ? "earned" : "empty")")
                }
            }
            Text(card.reward?.title ?? card.profile?.rewardMessage ?? GymVisitRules.defaultRewardMessage)
                .font(.title3.bold())
            if carriedOver > 0 {
                Text("Includes \(carriedOver) previously earned punches; visit dates weren’t supplied.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(card.archivedAt != nil ? "Reward claimed. Great work!" : card.completedAt == nil ? "Every visit gets you closer." : "All punches earned. Your reward is ready!")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(20).background(.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
    }
}
