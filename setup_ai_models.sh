#!/bin/bash
# ============================================
# Installation des dépendances IA pour AudiobookForge
# ============================================
# Usage :
#   cd /Volumes/J3THext/Audiobookforge
#   bash setup_ai_models.sh
# ============================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      AudiobookForge — Dépendances IA      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================
# 1. Vérifier / installer Homebrew
# ============================================
echo -e "${YELLOW}[1/4] Vérification de Homebrew...${NC}"
if ! command -v brew &>/dev/null; then
    echo -e "${RED}❌ Homebrew manquant. Installation...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
echo -e "${GREEN}✅ Homebrew OK${NC}"

# ============================================
# 2. Ollama + Qwen3 30B
# ============================================
echo ""
echo -e "${YELLOW}[2/4] Ollama + modèle Qwen3 30B...${NC}"

if ! command -v ollama &>/dev/null; then
    echo -e "   📦 Installation de Ollama..."
    brew install ollama
fi

# Vérifier si Ollama tourne
if ! pgrep -q Ollama; then
    echo -e "   🔄 Démarrage d'Ollama..."
    open -a Ollama
    sleep 3
fi

# Vérifier si le modèle est déjà présent
if ollama list 2>/dev/null | grep -q "qwen3:30b"; then
    echo -e "   ${GREEN}✅ Modèle qwen3:30b déjà présent${NC}"
else
    echo -e "   📥 Téléchargement de qwen3:30b (~18 Go)..."
    echo -e "   ${YELLOW}Cela peut prendre 15-30 minutes selon ta connexion.${NC}"
    ollama pull qwen3:30b
    echo -e "${GREEN}✅ qwen3:30b téléchargé${NC}"
fi
echo -e "${GREEN}✅ Ollama OK${NC}"

# ============================================
# 3. Python venv + mlx-speech
# ============================================
echo ""
echo -e "${YELLOW}[3/4] Environnement Python + mlx-speech...${NC}"

VENV_DIR="$DIR/backend/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo -e "   📦 Création du venv..."
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

echo -e "   📦 Mise à jour pip..."
pip install --upgrade pip --quiet

echo -e "   📦 Installation des dépendances Python..."
pip install -r "$DIR/backend/requirements.txt" --quiet

echo -e "   📦 Installation de mlx-speech..."
pip install mlx-speech --quiet

echo -e "   📦 Installation fastapi/uvicorn (API Docker)..."
pip install fastapi uvicorn --quiet

deactivate

echo -e "${GREEN}✅ Environnement Python OK${NC}"

# ============================================
# 4. Téléchargement du modèle Fish S2 Pro
# ============================================
echo ""
echo -e "${YELLOW}[4/4] Modèle Fish S2 Pro (mlx-speech)...${NC}"

source "$VENV_DIR/bin/activate"

echo -e "   📥 Téléchargement depuis Hugging Face (~1.5 Go)..."
echo -e "   ${YELLOW}Premier chargement : téléchargement automatique.${NC}"
python3 -c "
from mlx_speech import tts
print('   📥 Téléchargement du modèle fishaudio-s2-pro-8bit-mlx...')
model = tts.load('appautomaton/fishaudio-s2-pro-8bit-mlx')
print(f'   ✅ Modèle chargé !')
print(f'   📍 Cache: ~/.cache/huggingface/')
" 2>&1

deactivate

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Toutes les dépendances IA sont OK !   ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "Pour lancer l'application :"
echo -e "  ${BLUE}cd ${DIR} && bash run.sh${NC}"
echo ""
echo -e "Vérification :"
echo -e "  ${BLUE}ollama list${NC}    → doit montrer qwen3:30b"
echo -e "  ${BLUE}python3 -c 'from mlx_speech import tts; print(tts.list_models().keys())'${NC}   → doit fonctionner"
