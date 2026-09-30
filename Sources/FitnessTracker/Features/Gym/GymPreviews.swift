import SwiftUI
import SwiftData

@MainActor
private struct GymPreviewHost: View {
    private let container: ModelContainer
    private let selection: ProfileContext
    let punches: Int

    init(punches: Int) {
        self.punches = punches
        do {
            let previewContainer = try ModelContainerFactory.make(inMemory: true)
            let context = previewContainer.mainContext
            try SeedData.install(in: context, includePersonalValues: false)
            let profiles = try context.fetch(FetchDescriptor<Profile>())
            let owner = profiles.first(where: \.punchCardEnabled)!
            let service = GymVisitService(context: context)
            try service.prepareCards()
            for day in 0..<punches {
                let date = Calendar.current.date(byAdding: .day, value: day - punches, to: .now)!
                _ = try service.checkIn(profileIDs: [owner.id], date: date)
            }
            let profileContext = ProfileContext(defaults: nil)
            profileContext.select(owner)
            container = previewContainer
            selection = profileContext
        } catch { fatalError("Gym preview failed: \(error)") }
    }

    var body: some View {
        NavigationStack { GymRewardsHomeView() }.modelContainer(container).environment(selection)
    }
}

#Preview("Nine punches — check in for the reward") { GymPreviewHost(punches: 9) }
#Preview("Tenth punch celebration") { GymPreviewHost(punches: 10) }
#Preview("Punch card — dark, largest text") {
    GymPreviewHost(punches: 9).preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
}
#Preview("Celebration — light, largest text") {
    GymPreviewHost(punches: 10).preferredColorScheme(.light).dynamicTypeSize(.accessibility5)
}
