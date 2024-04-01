// swift-tools-version: 5.9

import PackageDescription
let sharedSwiftSettings: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "DistributedTracer",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DistributedTracer",
            targets: ["DistributedTracer"]),
    ],
    dependencies: [
        // Tracing
        .package(url: "https://github.com/slashmo/swift-otel", branch: "main"),
        // this ^^ brings in a MASSIVE cascade of dependencies
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        // MARK: - OTLP

        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.23.1"),

        // MARK: - Plugins

        .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),

    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "DistributedTracer",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "OTel", package: "swift-otel"),
                .product(name: "OTLPGRPC", package: "swift-otel"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "DistributedTracerTests",
            dependencies: ["DistributedTracer"],
            swiftSettings: sharedSwiftSettings
        ),
    ]
)
