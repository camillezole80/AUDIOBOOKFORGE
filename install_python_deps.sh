#!/bin/bash
# Script d'installation des dépendances Python pour AudiobookForge
# Usage: ./install_python_deps.sh

set -e

echo "🔧 Installation des dépendances Python pour AudiobookForge..."
echo ""

# Vérifier que Python 3 est installé
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 n'est pas installé"
    echo "   Installez-le avec: brew install python@3"
    exit 1
fi

echo "✅ Python version: $(python3 --version)"
echo ""

# Installer les dépendances depuis requirements.txt
echo "📦 Installation des dépendances depuis requirements.txt..."
python3 -m pip install --break-system-packages -r backend/requirements.txt

echo ""
echo "✅ Toutes les dépendances Python sont installées !"
echo ""
echo "📋 Dépendances installées :"
python3 -m pip list | grep -E "(mlx-speech|soundfile|ebooklib|beautifulsoup4|pymupdf|python-docx|httpx)"
