#!/bin/bash
# Quick build and test script for Mac File Explorer
# Usage: ./build-and-test.sh

set -e

echo "======================================"
echo "Mac File Explorer - Build & Test"
echo "======================================"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode command line tools not found"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Display Xcode version
XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo "✓ Found: $XCODE_VERSION"
echo ""

# Check if project file exists
if [ ! -f "MacFileExplorer.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: MacFileExplorer.xcodeproj not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo "🔨 Building MacFileExplorer (Debug configuration)..."
echo ""

# Build the project
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Debug \
           -quiet \
           clean build \
           CODE_SIGN_ENTITLEMENTS="MacFileExplorer/Supporting Files/MacFileExplorer.entitlements"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""

    # Find the built app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/MacFileExplorer-*/Build/Products/Debug -name "MacFileExplorer.app" -print -quit)

    if [ -n "$APP_PATH" ]; then
        echo "📍 App location: $APP_PATH"
        echo ""
        echo "🚀 Launching MacFileExplorer..."
        echo ""

        # Launch the app
        open "$APP_PATH"

        echo "======================================"
        echo "Test the following features:"
        echo "======================================"
        echo "1. ✓ Check 5 columns in list view"
        echo "2. ✓ Click column headers to sort"
        echo "3. ✓ Press Ctrl+\` for terminal"
        echo "4. ✓ Press Cmd+T for new tab"
        echo "5. ✓ Select folder & Shift+Cmd+C for colors"
        echo "======================================"
        echo ""
        echo "✨ Happy testing!"

    else
        echo "❌ Error: Could not find built application"
        echo "The build succeeded but the .app file was not found"
        exit 1
    fi
else
    echo ""
    echo "❌ Build failed!"
    echo ""
    echo "Common solutions:"
    echo "1. Clean build folder: rm -rf ~/Library/Developer/Xcode/DerivedData/MacFileExplorer-*"
    echo "2. Check Xcode version: xcodebuild -version (need 15.0+)"
    echo "3. Open in Xcode and check for errors: open MacFileExplorer.xcodeproj"
    exit 1
fi
