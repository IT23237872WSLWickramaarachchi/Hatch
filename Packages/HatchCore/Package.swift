// swift-tools-version: 5.9
//
// Package.swift — HatchCore
//
// Tools version 5.9 was introduced with Swift 5.9 / Xcode 15.0.
// Xcode 26.6 ships with Swift 6.x, which is backward-compatible with 5.9
// manifests, so this manifest works on both the university Macs and any
// Windows Swift 5.9+ toolchain you install.
//
// If you later need Swift 6 concurrency features (e.g. strict sendability),
// bump this line to: swift-tools-version: 6.0
// and update the package declaration accordingly.

import PackageDescription

let package = Package(
    name: "HatchCore",

    // HatchCore is pure Swift with no platform-specific code, so we declare
    // no platform constraints here. The iOS minimum deployment target (26.0)
    // is enforced by the Xcode app target, not by this package.
    products: [
        // A static library that the iOS app target links against.
        // "static" means the compiled code is copied into the app binary at
        // build time rather than loaded at runtime — the simplest choice for
        // a local package with no dynamic-linking requirements.
        .library(name: "HatchCore", targets: ["HatchCore"]),
    ],
    targets: [
        // The library target: every .swift file in Sources/HatchCore/ is
        // compiled into this library automatically.
        .target(
            name: "HatchCore",
            path: "Sources/HatchCore"
        ),

        // The test target: every .swift file in Tests/HatchCoreTests/ is
        // compiled into a test runner. It depends on HatchCore so it can
        // import and call the library's public API.
        .testTarget(
            name: "HatchCoreTests",
            dependencies: ["HatchCore"],
            path: "Tests/HatchCoreTests"
        ),
    ]
)
