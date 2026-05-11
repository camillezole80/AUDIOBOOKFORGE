##!/bin/bash
cd "$(dirname "$0")"

# Compiler l'application
echo "🔨 Compilation de AudiobookForge..."
swift build

# Lancer l'exécutable directement
echo "🚀 Lancement de AudiobookForge..."
.build/debug/AudiobookForge
