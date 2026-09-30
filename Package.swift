// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitnessTracker",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FitnessTracker", targets: ["FitnessTracker"]),
                .library(name: "WorkoutActivitySupport", targets: ["WorkoutActivitySupport"])],
    targets: [
        .target(name: "WorkoutActivitySupport"),
        .target(name: "FitnessTracker", dependencies: ["WorkoutActivitySupport"]),
        .testTarget(name: "FitnessTrackerTests", dependencies: ["FitnessTracker"])
    ]
)
