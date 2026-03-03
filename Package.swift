// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPhotoStudio",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GPhotoStudio", targets: ["GPhotoStudio"])
    ],
    targets: [
        .executableTarget(
            name: "GPhotoStudio"
        ),
        .testTarget(
            name: "GPhotoStudioTests",
            dependencies: ["GPhotoStudio"],
            path: "Tests/GPhotoStudioTests"
        )
    ]
)
