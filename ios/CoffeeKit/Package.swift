// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoffeeKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "CoffeeKit", targets: ["CoffeeKit"])
    ],
    targets: [
        .target(name: "CoffeeKit"),
        .testTarget(name: "CoffeeKitTests", dependencies: ["CoffeeKit"])
    ]
)
