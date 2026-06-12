// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MLEPEA",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MedicationLogicEngine", targets: ["MedicationLogicEngine"])
    ],
    targets: [
        .target(
            name: "MedicationLogicEngine",
            path: "Sources/MedicationLogicEngine"
        ),
        .testTarget(
            name: "MedicationLogicEngineTests",
            dependencies: ["MedicationLogicEngine"],
            path: "Tests/MedicationLogicEngineTests"
        )
    ]
)
