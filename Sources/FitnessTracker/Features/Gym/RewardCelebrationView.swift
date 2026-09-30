import SwiftUI

@MainActor
struct RewardCelebrationView: View {
    let card: PunchCard
    let errorMessage: String?
    let claim: () -> Void
    let later: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confettiStart = Date.now
    @State private var confettiVisible = true
    @AccessibilityFocusState private var headingFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [.pink.opacity(0.2), .purple.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if !reduceMotion && confettiVisible { ConfettiView(start: confettiStart).allowsHitTesting(false).accessibilityHidden(true) }
            ScrollView {
              VStack(spacing: 24) {
                HStack { Spacer(); ProfilePicker() }.padding(.top)
                Image(systemName: "gift.fill").font(.system(size: 84)).foregroundStyle(.pink).accessibilityHidden(true)
                Text("You did it, \(card.profile?.name ?? "champion")!")
                    .font(.largeTitle.bold()).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader).accessibilityFocused($headingFocused)
                Text("\(card.requiredVisits) gym visits. One well-earned reward.")
                    .font(.headline).multilineTextAlignment(.center)
                Text(card.reward?.title ?? GymVisitRules.defaultRewardMessage)
                    .font(.title2.bold()).multilineTextAlignment(.center)
                if let errorMessage { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.primary).font(.subheadline) }
                Button(action: claim) {
                    Label("Claim reward", systemImage: "gift.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 56)
                }.buttonStyle(.borderedProminent).tint(AppColors.stampFill).controlSize(.large)
                    .accessibilityHint("Archives this card and starts your next punch card.")
                Button(action: later) { Text("Later").frame(maxWidth: .infinity, minHeight: 48) }
              }.frame(maxWidth: 560).padding(24).frame(maxWidth: .infinity)
            }
        }
        .background(.background)
        .interactiveDismissDisabled()
        .task(id: card.id) {
            confettiStart = .now
            confettiVisible = true
            headingFocused = true
            GymHaptics.celebrate()
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            confettiVisible = false
        }
    }
}

private struct ConfettiView: View {
    let start: Date
    private let colors: [Color] = [.pink, .purple, .orange, .yellow, .mint, .blue]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let elapsed = max(0, timeline.date.timeIntervalSince(start))
                // Deterministic particles avoid random jumps on SwiftUI redraws; no dependencies.
                for index in 0..<70 {
                    let speed = 0.16 + Double(index % 7) * 0.025
                    let phase = (elapsed * speed + Double(index) * 0.037).truncatingRemainder(dividingBy: 1)
                    let origin = Double((index * 37) % 100) / 100
                    let x = origin * size.width + sin(elapsed * 2 + Double(index)) * 20
                    let y = phase * (size.height + 60) - 30
                    var particle = context
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(elapsed * Double(35 + index % 80)))
                    particle.fill(Path(CGRect(x: -4, y: -7, width: 8, height: 14)), with: .color(colors[index % colors.count]))
                }
            }
        }.ignoresSafeArea()
    }
}
