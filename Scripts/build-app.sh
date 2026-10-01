#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
if [ "${TAP_UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    binary_dir=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
else
    swift build -c release
    binary_dir=$(swift build -c release --show-bin-path)
fi
app="$project_dir/dist/Tap.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$project_dir/.build/Tap.iconset"
cp "$binary_dir/Tap" "$app/Contents/MacOS/Tap"
cp Sources/Tap/Resources/panel.html "$app/Contents/Resources/panel.html"
xcrun swift Scripts/Icon.swift "$project_dir/.build/Tap.iconset"
iconutil -c icns "$project_dir/.build/Tap.iconset" -o "$app/Contents/Resources/Tap.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.shkienao-pixel.tap</string>
<key>CFBundleExecutable</key><string>Tap</string>
<key>CFBundleName</key><string>Tap</string>
<key>CFBundleDisplayName</key><string>Tap</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>Tap</string>
<key>CFBundleShortVersionString</key><string>0.2.0-beta.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "${TAP_SIGN_IDENTITY:--}" "$app"
"$app/Contents/MacOS/Tap" --self-check
codesign --verify --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$project_dir/dist/Tap-macOS.zip"
printf '\nBuilt %s\nArchive: %s\n' "$app" "$project_dir/dist/Tap-macOS.zip"
