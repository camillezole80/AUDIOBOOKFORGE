#!/bin/bash
# ============================================
# Lance AudiobookForge directement
# (préserve PATH + variables d'env)
# Cmd+Q fonctionne nativement avec SwiftUI
# ============================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AudiobookForge"
BUILD_DIR="$DIR/.build/debug"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BINARY="$BUILD_DIR/$APP_NAME"

echo "🔨 Build..."
cd "$DIR"
swift build 2>&1 | tail -3

echo "📦 Mise à jour du bundle .app..."
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$DIR/AudiobookForge/Info.plist" "$APP_BUNDLE/Contents/"

# Config Info.plist
PLIST="$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$PLIST" 2>/dev/null || true

# Icône app : disque bleu simple (placeholder)
ICON="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
if [ ! -f "$ICON" ]; then
  python3 << 'PYEOF' 2>/dev/null || true
import struct, zlib
# Générer un PNG 64×64 : cercle bleu
w,h=64,64
raw=b''
for y in range(h):
  raw+=b'\x00'
  for x in range(w):
    d=((x-32)**2+(y-32)**2)**0.5
    if d<28:   raw+=struct.pack('BBBB',0,122,255,255)
    elif d<30: raw+=struct.pack('BBBB',0,100,200,255)
    else:      raw+=struct.pack('BBBB',0,0,0,0)
rows=raw
# Construire PNG
p=b'\x89PNG\r\n\x1a\n'
ihdr=struct.pack('>IIBBBBB',w,h,8,6,0,0,0)
p+=struct.pack('>I',13)+b'IHDR'+ihdr+struct.pack('>I',zlib.crc32(b'IHDR'+ihdr)&0xFFFFFFFF)
c=zlib.compress(rows)
p+=struct.pack('>I',len(c))+b'IDAT'+c+struct.pack('>I',zlib.crc32(b'IDAT'+c)&0xFFFFFFFF)
p+=struct.pack('>I',0)+b'IEND'+struct.pack('>I',zlib.crc32(b'IEND')&0xFFFFFFFF)
with open('/Volumes/J3THext/Audiobookforge/AudiobookForge/AppIcon.png','wb') as f: f.write(p)
PYEOF
  cp "$DIR/AudiobookForge/AppIcon.png" "$ICON" 2>/dev/null || true
fi

echo "🚀 Lancement de $APP_NAME..."
# Lancer directement depuis le terminal pour préserver PATH et l'env
cd "$DIR"
AUDIOBOOKFORGE_ROOT="$DIR" PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
