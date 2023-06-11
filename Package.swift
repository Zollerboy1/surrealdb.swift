// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SurrealDB",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SurrealDB",
            targets: ["SurrealDB"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-syntax.git", revision: "swift-5.9-DEVELOPMENT-SNAPSHOT-2023-06-05-a"),
        .package(url: "https://github.com/rwbutler/LetterCase.git", from: "1.6.1"),
        .package(url: "https://github.com/yaslab/ULID.swift.git", from: "1.2.0"),
        .package(url: "https://github.com/Zollerboy1/BigDecimal.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SurrealDBCore",
            dependencies: [
                "BigDecimal",
                .product(name: "ULID", package: "ULID.swift")
            ]
        ),
        .macro(
            name: "SurrealDBMacroImpl",
            dependencies: [
                "LetterCase",
                "SurrealDBCore",
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(
            name: "SurrealDB",
            dependencies: [
                "BigDecimal",
                "SurrealDBCore",
                "SurrealDBMacroImpl",
                .product(name: "ULID", package: "ULID.swift")
            ]
        ),
        .executableTarget(name: "Test", dependencies: ["SurrealDB"]),
        .testTarget(
            name: "SurrealDBTests",
            dependencies: [
                "SurrealDB",
                "SurrealDBMacroImpl",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        ),
    ]
)
