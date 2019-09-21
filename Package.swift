// swift-tools-version:5.0
import PackageDescription


let package = Package(
	name: "CollectionAndTableViewUpdateConveniences",
	platforms: [.iOS(.v8) /* Technically iOS 3! */],
	products: [
		.library(name: "CollectionAndTableViewUpdateConveniences", targets: ["CollectionAndTableViewUpdateConveniences"]),
	],
	targets: [
		.target(name: "CollectionAndTableViewUpdateConveniences", dependencies: [], path: "CollectionAndTableViewUpdateConveniences")
	]
)
