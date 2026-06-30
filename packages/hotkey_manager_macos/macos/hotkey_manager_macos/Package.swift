// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hotkey_manager_macos",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "hotkey-manager-macos", targets: ["hotkey_manager_macos"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .target(
            name: "hotkey_manager_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "HotKey", package: "HotKey")
            ],
            path: "Classes"
        )
    ]
)
