#!/bin/bash
# Script d'installation des environnements virtuels pour tts-audiobook-tool
# Usage: ./setup_venvs.sh [fish-s2|chatterbox|qwen3|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que Python 3.11 et 3.12 sont installés
check_python_versions() {
    log_info "Vérification des versions Python..."
    
    if ! command -v python3.11 &> /dev/null; then
        log_error "Python 3.11 n'est pas installé"
        log_info "Installation: brew install python@3.11"
        exit 1
    fi
    
    if ! command -v python3.12 &> /dev/null; then
        log_error "Python 3.12 n'est pas installé"
        log_info "Installation: brew install python@3.12"
        exit 1
    fi
    
    log_info "✓ Python 3.11: $(python3.11 --version)"
    log_info "✓ Python 3.12: $(python3.12 --version)"
}

# Installer Fish S2-Pro
install_fish_s2() {
    log_info "═══════════════════════════════════════"
    log_info "Installation de Fish S2-Pro (Python 3.12)"
    log_info "═══════════════════════════════════════"
    
    if [ -d "venv-fish-s2" ]; then
        log_warn "venv-fish-s2 existe déjà, suppression..."
        rm -rf venv-fish-s2
    fi
    
    log_info "Création de l'environnement virtuel..."
    python3.12 -m venv venv-fish-s2
    
    log_info "Activation et installation des dépendances..."
    source venv-fish-s2/bin/activate
    
    pip install --upgrade pip
    pip install -r requirements-fish-s2.txt
    
    log_info "Installation de PyTorch avec CUDA 12.8..."
    pip uninstall -y torch torchaudio
    pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
    
    log_info "Test de l'installation..."
    python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
    
    deactivate
    
    log_info "✓ Fish S2-Pro installé avec succès"
    log_warn "N'oubliez pas d'authentifier HuggingFace:"
    log_warn "  source venv-fish-s2/bin/activate"
    log_warn "  huggingface-cli login"
    log_warn "  deactivate"
}

# Installer Chatterbox
install_chatterbox() {
    log_info "═══════════════════════════════════════"
    log_info "Installation de Chatterbox (Python 3.11)"
    log_info "═══════════════════════════════════════"
    
    if [ -d "venv-chatterbox" ]; then
        log_warn "venv-chatterbox existe déjà, suppression..."
        rm -rf venv-chatterbox
    fi
    
    log_info "Création de l'environnement virtuel..."
    python3.11 -m venv venv-chatterbox
    
    log_info "Activation et installation des dépendances..."
    source venv-chatterbox/bin/activate
    
    pip install --upgrade pip
    pip install -r requirements-chatterbox.txt
    
    log_info "Installation de PyTorch avec CUDA 12.4..."
    pip uninstall -y torch torchaudio
    pip install torch==2.6.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
    
    log_info "Test de l'installation..."
    python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
    
    deactivate
    
    log_info "✓ Chatterbox installé avec succès"
}

# Installer Qwen3-TTS
install_qwen3() {
    log_info "═══════════════════════════════════════"
    log_info "Installation de Qwen3-TTS (Python 3.12)"
    log_info "═══════════════════════════════════════"
    
    if [ -d "venv-qwen3tts" ]; then
        log_warn "venv-qwen3tts existe déjà, suppression..."
        rm -rf venv-qwen3tts
    fi
    
    log_info "Création de l'environnement virtuel..."
    python3.12 -m venv venv-qwen3tts
    
    log_info "Activation et installation des dépendances..."
    source venv-qwen3tts/bin/activate
    
    pip install --upgrade pip
    pip install -r requirements-qwen3tts.txt
    
    log_info "Installation de PyTorch avec CUDA 12.8..."
    pip uninstall -y torch torchaudio
    pip install torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128
    
    log_info "Installation de Flash Attention (optionnel)..."
    if pip install flash-attn==2.8.3 --no-build-isolation; then
        log_info "✓ Flash Attention installé"
    else
        log_warn "Flash Attention non installé (optionnel)"
    fi
    
    log_info "Test de l'installation..."
    python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
    
    deactivate
    
    log_info "✓ Qwen3-TTS installé avec succès"
}

# Rendre le wrapper exécutable
setup_wrapper() {
    log_info "Configuration du wrapper..."
    chmod +x audiobook_tool_wrapper.py
    log_info "✓ Wrapper configuré"
}

# Menu principal
main() {
    check_python_versions
    
    case "${1:-all}" in
        fish-s2)
            install_fish_s2
            ;;
        chatterbox)
            install_chatterbox
            ;;
        qwen3)
            install_qwen3
            ;;
        all)
            install_fish_s2
            echo ""
            install_chatterbox
            echo ""
            install_qwen3
            ;;
        *)
            log_error "Usage: $0 [fish-s2|chatterbox|qwen3|all]"
            exit 1
            ;;
    esac
    
    echo ""
    setup_wrapper
    
    echo ""
    log_info "═══════════════════════════════════════"
    log_info "Installation terminée !"
    log_info "═══════════════════════════════════════"
    echo ""
    log_info "Prochaines étapes:"
    log_info "1. Authentifier HuggingFace pour Fish S2-Pro:"
    log_info "   source venv-fish-s2/bin/activate"
    log_info "   huggingface-cli login"
    log_info "   deactivate"
    echo ""
    log_info "2. Tester le wrapper:"
    log_info "   source venv-fish-s2/bin/activate"
    log_info "   python audiobook_tool_wrapper.py --help"
    log_info "   deactivate"
}

main "$@"
