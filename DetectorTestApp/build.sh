#!/bin/bash
set -euo pipefail

APP_NAME="DetectorTestApp"

echo "=== Building $APP_NAME ==="
cd "$(dirname "$0")"

swift build -c release 2>&1

# Find the built binary
BINARY=$(swift build -c release --show-bin-path)/$APP_NAME

# Create .app bundle
APP_DIR="${APP_NAME}.app/Contents/MacOS"
mkdir -p "$APP_DIR"
cp "$BINARY" "$APP_DIR/$APP_NAME"

# Create Info.plist
cat > "${APP_NAME}.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.himi.detector-test</string>
    <key>CFBundleName</key>
    <string>Recording Detector</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo ""
echo "=== Build complete ==="
echo "Run with: open ${APP_NAME}.app"
echo "Or:       ./${APP_DIR}/${APP_NAME}"
