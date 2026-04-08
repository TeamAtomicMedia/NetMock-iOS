// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetMock",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NetMockCore",
            targets: ["NetMockCore"],
        ),
        .library(
            name: "NetMock",
            targets: ["NetMock", "NetMockCore"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/TeamAtomicMedia/Parser-iOS.git", from: "2.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NetMockCore",
            dependencies: [.product(name: "Parser", package: "Parser-iOS")]
        ),
        .target(
            name: "NetMock",
            dependencies: ["NetMockCore"],
        ),
        .testTarget(
            name: "NetMockTests",
            dependencies: [
                "NetMock",
                "NetMockCore",
                .product(name: "Parser", package: "Parser-iOS")
            ],
            resources: [.process("Support/Responses")],
        ),
    ],
    swiftLanguageModes: [.v6]
)
