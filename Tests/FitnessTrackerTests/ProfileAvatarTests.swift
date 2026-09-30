import XCTest
import SwiftData
@testable import FitnessTracker

final class ProfileAvatarTests: XCTestCase {
    @MainActor func testAvatarDraftPersistenceIsolationReplacementAndRemoval() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let hai = try XCTUnwrap(profiles.first { !$0.punchCardEnabled })
        let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
        let historyIDs = Set(hai.sessions.map(\.id))
        let punches = qi.punchCards.first?.progress
        // Valid 1×1 PNG; image normalization is separately covered by ExerciseEditorTests.
        let photo = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1sAAAAASUVORK5CYII="))
        let draft = ProfileAvatarViewModel(profile: hai)
        draft.avatarData = photo
        XCTAssertNil(hai.avatarData, "Unsaved edits must not change the profile")
        draft.isLoading = true
        XCTAssertFalse(draft.save(in: context))
        XCTAssertNil(hai.avatarData)
        draft.isLoading = false
        XCTAssertTrue(draft.save(in: context))
        XCTAssertNil(qi.avatarData)
        let id = hai.id
        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Profile>(predicate: #Predicate { $0.id == id })).first?.avatarData, photo)
        let qiDraft = ProfileAvatarViewModel(profile: qi)
        qiDraft.avatarData = photo
        XCTAssertTrue(qiDraft.save(in: context))
        let removal = ProfileAvatarViewModel(profile: hai)
        removal.avatarData = nil
        XCTAssertEqual(hai.avatarData, photo, "Cancelling removal retains the photo")
        XCTAssertTrue(removal.save(in: context))
        XCTAssertNil(hai.avatarData)
        XCTAssertEqual(qi.avatarData, photo)
        try SeedData.install(in: context)
        XCTAssertEqual(qi.avatarData, photo, "Seed migrations preserve avatars")
        XCTAssertEqual(Set(hai.sessions.map(\.id)), historyIDs)
        XCTAssertEqual(qi.punchCards.first?.progress, punches)
    }
}
