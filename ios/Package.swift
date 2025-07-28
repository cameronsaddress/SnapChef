// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SnapChef",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SnapChef",
            targets: ["SnapChef"]
        ),
    ],
    dependencies: [
        // Google Sign-In SDK
        .package(url: "https://github.com/google/GoogleSignIn-iOS", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "SnapChef",
            dependencies: [
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "SnapChef",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SnapChefTests",
            dependencies: ["SnapChef"],
            path: "SnapChefTests"
        ),
    ]
)