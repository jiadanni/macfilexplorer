#!/bin/bash
# Build and install Mac File Explorer to /Applications
# Usage: ./install-release.sh

set -e

echo "======================================"
echo "Mac File Explorer - Release Build"
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

# Create build directory
BUILD_DIR="./build"
echo "📁 Creating build directory..."
mkdir -p "$BUILD_DIR"
echo ""

echo "🔨 Building MacFileExplorer (Release configuration)..."
echo "This may take a minute..."
echo ""

# Build the project in Release mode
xcodebuild -project MacFileExplorer.xcodeproj \
           -scheme MacFileExplorer \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           clean build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""

    APP_PATH="$BUILD_DIR/Build/Products/Release/MacFileExplorer.app"

    if [ -d "$APP_PATH" ]; then
        echo "📍 Built app location: $APP_PATH"

        # Get app size
        APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
        echo "📦 App size: $APP_SIZE"
        echo ""

        # Ask user if they want to install
        read -p "Install to /Applications? [y/N] " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "📥 Installing to /Applications..."

            # Remove old version if it exists
            if [ -d "/Applications/MacFileExplorer.app" ]; then
                echo "⚠️  Removing old version..."
                sudo rm -rf "/Applications/MacFileExplorer.app"
            fi

            # Copy new version
            sudo cp -r "$APP_PATH" /Applications/

            # Remove quarantine attribute
            echo "🔓 Removing quarantine attribute..."
            sudo xattr -cr /Applications/MacFileExplorer.app

            echo ""
            echo "✅ Installation complete!"
            echo ""

            # Ask if user wants to launch
            read -p "Launch MacFileExplorer now? [y/N] " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo ""
                echo "🚀 Launching MacFileExplorer..."
                open /Applications/MacFileExplorer.app
                echo ""
                echo "💡 Tip: Right-click the app in your Dock and select"
                echo "   'Options > Keep in Dock' for quick access"
            fi
        else
            echo ""
            echo "✅ Build completed but not installed"
            echo "📍 You can run it from: $APP_PATH"
            echo ""
            echo "To install manually:"
            echo "  sudo cp -r \"$APP_PATH\" /Applications/"
            echo "  sudo xattr -cr /Applications/MacFileExplorer.app"
        fi

        echo ""
        echo "======================================"
        echo "Release build information:"
        echo "======================================"
        echo "Build type:    Release (Optimized)"
        echo "Location:      $APP_PATH"
        echo "Size:          $APP_SIZE"
        echo "======================================"

    else
        echo "❌ Error: Could not find built application"
        echo "Expected location: $APP_PATH"
        exit 1
    fi
else
    echo ""
    echo "❌ Build failed!"
    echo ""
    echo "Common solutions:"
    echo "1. Clean the project: rm -rf ./build"
    echo "2. Check Xcode version: xcodebuild -version (need 15.0+)"
    echo "3. Open in Xcode and check for errors: open MacFileExplorer.xcodeproj"
    exit 1
fi

echo ""
echo "✨ Done!"
