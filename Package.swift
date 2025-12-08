// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KeetaClient",
    platforms: [.iOS("15.0"), .macOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "KeetaClient",
            targets: ["KeetaClient"]),
    ],
    dependencies: [
        .package(name: "swift-secp256k1", url: "https://github.com/21-DOT-DEV/swift-secp256k1", from: "0.21.1"),
        .package(url: "https://github.com/pebble8888/ed25519swift.git", .upToNextMajor(from: "1.2.7")),
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMajor(from: "5.3.0")),
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.3.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.8.5")),
        .package(url: "https://github.com/KeetaNetwork/PotentCodables.git", branch: "der-generalized-time-omit-zeros"),
        .package(url: "https://github.com/bitmark-inc/bip39-swift.git", from: "1.0.1"),
        .package(url: "https://github.com/norio-nomura/Base32.git", from: "0.5.4")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "KeetaClient",
            dependencies: [
                .product(name: "P256K", package: "swift-secp256k1"),
                "ed25519swift",
                "BigInt",
                "CryptoSwift",
                "PotentCodables",
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .product(name: "BIP39", package: "bip39-swift"),
                "Base32"
            ]),
        .testTarget(
            name: "KeetaClientTests",
            dependencies: ["KeetaClient"]),
    ]
)
