import XCTest
import SwiftData
import ImageIO
import UniformTypeIdentifiers
@testable import FitnessTracker

final class ExerciseEditorTests: XCTestCase {
    @MainActor func testAddEditAndDuplicateValidationAreProfileScoped() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let me = Profile(name: "Me")
        let qi = Profile(name: "Qi")
        context.insert(me)
        context.insert(qi)
        try context.save()
        let add = ExerciseEditorViewModel(profileID: qi.id)
        add.name = "  Step up  "
        add.muscleGroup = "Legs"
        add.equipment = "Dumbbells"
        let exercise = try XCTUnwrap(add.save(in: context))
        XCTAssertEqual(exercise.name, "Step up")
        XCTAssertEqual(exercise.profile?.id, qi.id)
        XCTAssertTrue(me.exercises.isEmpty)
        let duplicate = ExerciseEditorViewModel(profileID: qi.id)
        duplicate.name = "step UP"
        XCTAssertNil(duplicate.save(in: context))
        let own = ExerciseEditorViewModel(profileID: me.id)
        own.name = "Step up"
        XCTAssertNotNil(own.save(in: context))
        let edit = ExerciseEditorViewModel(profileID: qi.id, exercise: exercise)
        edit.name = "Weighted step up"
        edit.loadNotes = "Per dumbbell"
        edit.unit = .lb
        XCTAssertNotNil(edit.save(in: context))
        XCTAssertEqual(exercise.loadNotes, "Per dumbbell")
        XCTAssertEqual(exercise.weightIncrement, 5.51, accuracy: 0.01)
        XCTAssertEqual(qi.exercises.count, 1)
        let wrongOwner = ExerciseEditorViewModel(profileID: me.id, exercise: exercise)
        XCTAssertNil(wrongOwner.save(in: context))
    }

    @MainActor func testPhotoPreparationPersistenceAndRemoval() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let profile = Profile(name: "Qi")
        context.insert(profile)
        try context.save()
        let bitmap = try XCTUnwrap(CGContext(data: nil, width: 1600, height: 800, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        bitmap.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        bitmap.fill(CGRect(x: 0, y: 0, width: 1600, height: 800))
        let image = try XCTUnwrap(bitmap.makeImage())
        let input = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(input, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let prepared = try ExercisePhoto.prepare(input as Data)
        let preparedImage = try XCTUnwrap(ExercisePhoto.image(from: prepared))
        XCTAssertLessThanOrEqual(max(preparedImage.width, preparedImage.height), 1200)
        XCTAssertThrowsError(try ExercisePhoto.prepare(Data("not an image".utf8)))
        let add = ExerciseEditorViewModel(profileID: profile.id)
        add.name = "Step up"
        add.photoData = prepared
        let exercise = try XCTUnwrap(add.save(in: context))
        let id = exercise.id
        let fresh = ModelContext(container)
        let saved = try XCTUnwrap(fresh.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })).first)
        XCTAssertEqual(saved.photoData, prepared)
        let edit = ExerciseEditorViewModel(profileID: profile.id, exercise: exercise)
        edit.photoData = nil
        XCTAssertNotNil(edit.save(in: context))
        XCTAssertNil(exercise.photoData)
    }
}
