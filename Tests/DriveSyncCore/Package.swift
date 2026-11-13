// swift-tools-version:5.9
//
// Manic MP: the Google Drive memory-card sync, built and tested on the Mac
// without the app. Sources/DriveSyncCore holds symlinks to the two
// Foundation-only files of ManicEmu/Sources/Business/DriveSync.
//
//   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Tests/DriveSyncCore
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import PackageDescription

let package = Package(
    name: "DriveSyncCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "DriveSyncCore"),
        .testTarget(name: "DriveSyncCoreTests", dependencies: ["DriveSyncCore"]),
    ]
)
