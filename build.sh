#!/bin/bash
set -e

# Himi Recorder - Build, Sign & Deploy Script
# Usage: ./build.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="HimiRecorder"
BUNDLE_ID="com.himi.recorder"
APP_DIR="${SCRIPT_DIR}/${APP_NAME}.app"

echo "🔨 Building ${APP_NAME} (Release)..."
cd "${SCRIPT_DIR}"
swift build -c release

echo "📦 Packaging ${APP_NAME}.app..."

# Create .app bundle structure
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp -f "${SCRIPT_DIR}/.build/release/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist (from source, with real values)
cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh_CN</string>
	<key>CFBundleExecutable</key>
	<string>${APP_NAME}</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Himi Recorder</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.2.0</string>
	<key>CFBundleVersion</key>
	<string>200</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026. All rights reserved.</string>
	<key>NSScreenCaptureUsageDescription</key>
	<string>Himi Recorder 需要屏幕录制权限来录制您选定的屏幕区域。</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

# Copy app icon (.icns) to Resources
ICNS_SRC="${SCRIPT_DIR}/HimiRecorder/Assets.xcassets/AppIcon.appiconset/AppIcon.icns"
if [ -f "${ICNS_SRC}" ]; then
    cp -f "${ICNS_SRC}" "${APP_DIR}/Contents/Resources/AppIcon.icns"
    echo "🎨 Copied AppIcon.icns"
fi

# Copy SPM-compiled resource bundles (contains Assets.car with AppIcon & MenuBarIcon)
BUNDLE_SRC="${SCRIPT_DIR}/.build/release/HimiRecorder_HimiRecorder.bundle"
if [ -d "${BUNDLE_SRC}" ]; then
    cp -Rf "${BUNDLE_SRC}" "${APP_DIR}/Contents/Resources/"
    echo "📦 Copied resource bundle"
fi

# Write PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Sign the app with ad-hoc signature bound to bundle ID
echo "🔏 Signing with ad-hoc identity (bundle ID: ${BUNDLE_ID})..."
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP_DIR}"

echo ""
echo "✅ Build complete!"
echo ""
echo "   ${APP_DIR}"
echo ""
echo "Usage:"
echo "   open ${APP_DIR}"
echo ""
echo "Or copy to /Applications:"
echo "   cp -R ${APP_DIR} /Applications/"
echo ""
echo "⚠️  First launch: grant Screen Recording permission in"
echo "   System Settings → Privacy & Security → Screen Recording"
