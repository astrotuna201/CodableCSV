// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "CodableCSV",
  platforms: [
    .macOS(.v13), .iOS(.v12), .tvOS(.v12), .watchOS(.v4)
  ],
  products: [
    .library(name: "CodableCSV", targets: ["CodableCSV"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "CodableCSV", dependencies: [], path: "sources"),
    .testTarget(name: "CodableCSVTests", dependencies: ["CodableCSV"], path: "tests"),
    .testTarget(name: "CodableCSVBenchmarks", dependencies: ["CodableCSV"], path: "benchmarks")
  ]
)
