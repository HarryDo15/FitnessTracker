// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FitnessTracker",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FitnessTracker", targets: ["FitnessTracker"])],
    targets: [
        .target(name: "FitnessTracker"),
        .testTarget(name: "FitnessTrackerTests", dependencies: ["FitnessTracker"])
    ]
)
