#!/bin/bash

# Script pour créer un bundle .app avec icône pour AudiobookForge

set -e

echo "🔨 Création du bundle AudiobookForge.app..."

# Nettoyer l'ancien bundle
rm -rf AudiobookForge.app

# Créer la structure du bundle
mkdir -p AudiobookForge.app/Contents/MacOS
mkdir -p AudiobookForge.app/Contents/Resources

# Copier l'exécutable
echo "📦 Copie de l'exécutable..."
cp .build/debug/AudiobookForge AudiobookForge.app/Contents/MacOS/

# Créer l'icône .icns à partir des PNG
echo "🎨 Création de l'icône .icns..."
mkdir -p /tmp/AppIcon.iconset
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-16.png /tmp/AppIcon.iconset/icon_16x16.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png /tmp/AppIcon.iconset/icon_16x16@2x.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-32.png /tmp/AppIcon.iconset/icon_32x32.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-64.png /tmp/AppIcon.iconset/icon_32x32@2x.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png /tmp/AppIcon.iconset/icon_128x128.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png /tmp/AppIcon.iconset/icon_128x128@2x.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png /tmp/AppIcon.iconset/icon_256x256.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png /tmp/AppIcon.iconset/icon_256x256@2x.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-512.png /tmp/AppIcon.iconset/icon_512x512.png
cp AudiobookForge/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png /tmp/AppIcon.iconset/icon_512x512@2x.png

iconutil -c icns /tmp/AppIcon.iconset -o AudiobookForge.app/Contents/Resources/AppIcon.icns
rm -rf /tmp/AppIcon.iconset

# Créer Info.plist
echo "📝 Création du Info.plist..."
cat > AudiobookForge.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AudiobookForge</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.audiobookforge.app</string>
    <key>CFBundleName</key>
    <string>AudiobookForge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 AudiobookForge</string>
</dict>
</plist>
EOF

# Rendre l'exécutable... exécutable
chmod +x AudiobookForge.app/Contents/MacOS/AudiobookForge

echo "✅ Bundle créé : AudiobookForge.app"
echo ""
echo "Pour lancer l'application :"
echo "  open AudiobookForge.app"
echo ""
echo "Pour l'ajouter au Dock :"
echo "  1. Ouvrez AudiobookForge.app"
echo "  2. Clic droit sur l'icône dans le Dock"
echo "  3. Options > Garder dans le Dock"
