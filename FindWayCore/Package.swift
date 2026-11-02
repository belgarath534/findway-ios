// swift-tools-version:5.9
// FindWayCore holds the parts of FindWay that do not need a camera:
// the trail map, path finding, turn-by-turn directions and the scan coach.
// Keeping them here means they can be tested on any computer with `swift test`.
import PackageDescription

let package = Package(
    name: "FindWayCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "FindWayCore", targets: ["FindWayCore"])
    ],
    targets: [
        .target(name: "FindWayCore"),
        .testTarget(name: "FindWayCoreTests", dependencies: ["FindWayCore"])
    ]
)
