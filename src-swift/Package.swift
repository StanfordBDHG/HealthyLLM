// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenTSLMKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "OpenTSLMKit", targets: ["OpenTSLMKit"]),
        .executable(name: "OpenTSLMRunner", targets: ["OpenTSLMRunner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.2"),
    ],
    targets: [
        .target(
            name: "OpenTSLMKit",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
            ]
        ),
        .executableTarget(
            name: "OpenTSLMRunner",
            dependencies: [
                "OpenTSLMKit",
                .product(name: "MLX", package: "mlx-swift"),
            ]
        ),
        .testTarget(
            name: "OpenTSLMKitTests",
            dependencies: [
                "OpenTSLMKit",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
            ],
            resources: [
                .copy("Fixtures/encoder_io.npz"),
                .copy("Fixtures/encoder_io.safetensors"),
                .copy("Fixtures/encoder_weights.safetensors"),
            ]
        ),
    ]
)
