#!/bin/bash

# Simple test runner script for MacFileExplorer
# This creates a temporary Swift package to run the tests

echo "MacFileExplorer Test Runner"
echo "============================"
echo ""

# Create a temporary directory for testing
TEMP_DIR=$(mktemp -d)
echo "Creating temporary test environment in: $TEMP_DIR"

# Copy source files to temp directory
cp -r MacFileExplorer/Sources "$TEMP_DIR/"
cp -r MacFileExplorerTests "$TEMP_DIR/"

# Remove AppDelegate.swift from the library build (it has @main which conflicts with test runner)
rm "$TEMP_DIR/Sources/AppDelegate.swift"

cd "$TEMP_DIR"

# Create Package.swift
cat > Package.swift << 'EOF'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacFileExplorer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MacFileExplorer",
            targets: ["MacFileExplorer"]),
    ],
    targets: [
        .target(
            name: "MacFileExplorer",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "MacFileExplorerTests",
            dependencies: ["MacFileExplorer"],
            path: "MacFileExplorerTests"),
    ]
)
EOF

echo "Running tests..."
echo ""

swift test

TEST_RESULT=$?

# Clean up
cd -
rm -rf "$TEMP_DIR"

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Tests failed with exit code: $TEST_RESULT"
fi

exit $TEST_RESULT
