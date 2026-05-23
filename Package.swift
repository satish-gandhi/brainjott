// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchNotes", targets: ["NotchNotes"])
    ],
    targets: [
        .executableTarget(
            name: "NotchNotes",
            path: "Sources/NotchNotes"
        ),
        .testTarget(
            name: "NotchNotesTests",
            dependencies: ["NotchNotes"],
            path: "Tests/NotchNotesTests"
        )
    ]
)
