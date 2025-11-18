// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TechHouseApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TechHouseApp",
            targets: ["TechHouseApp"]
        )
    ],
    targets: [
        .target(
            name: "TechHouseApp",
            path: "TechHouseApp/Sources/TechHouseApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "TechHouseAppTests",
            dependencies: ["TechHouseApp"],
            path: "TechHouseApp/Tests/TechHouseAppTests"
        )
    ]
)
