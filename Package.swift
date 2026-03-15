// swift-tools-version: 6.0
// Brazos — Form-Constrained Generation Engine
// Copyright © 2026 Jared Lewis / PARCRI
// All prior work (Newton, Ada, THIA, LYRA, BILL, ATKINS, Shape Theory,
// Kinematic Linguistics, Le Bézier du calcul, 1==1 Canon,
// "Verification is Computation," DIL, HumanLogica, TinyTalk)
// constitutes foundational research for this substrate.

import PackageDescription

let package = Package(
    name: "Brazos",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .library(name: "Brazos", targets: ["Brazos"]),
        .library(name: "BrazosTEKS", targets: ["BrazosTEKS"])
    ],
    targets: [
        .target(
            name: "Brazos",
            path: "Sources/Brazos"
        ),
        .target(
            name: "BrazosTEKS",
            dependencies: ["Brazos"],
            path: "Sources/BrazosTEKS"
        ),
        .testTarget(
            name: "BrazosTests",
            dependencies: ["Brazos", "BrazosTEKS"],
            path: "Tests/BrazosTests"
        )
    ]
)
