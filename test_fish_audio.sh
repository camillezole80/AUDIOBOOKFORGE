#!/bin/bash

# Script de test rapide Fish.Audio
# Usage: ./test_fish_audio.sh

echo "🐟 Test rapide Fish.Audio"
echo "========================="
echo ""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Vérifier la clé API dans le Keychain
info "1. Vérification de la clé API dans le Keychain..."
if API_KEY=$(security find-generic-password -s "fish_audio_api_key" -w 2>/dev/null); then
    success "Clé API trouvée dans le Keychain"
    echo "   Clé: ${API_KEY:0:10}...${API_KEY: -5}"
else
    error "Aucune clé API trouvée dans le Keychain"
    echo ""
    echo "Pour configurer votre clé API, lancez :"
    echo "  ./configure_fish_audio.sh"
    echo ""
    exit 1
fi
echo ""

# 2. Tester la connexion à Fish.Audio
info "2. Test de connexion à Fish.Audio..."

TEMP_JSON=$(mktemp)
cat > "$TEMP_JSON" <<EOF
{
    "text": "Test de connexion AudiobookForge.",
    "format": "wav"
}
EOF

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://api.fish.audio/v1/tts" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -H "model: s2-pro" \
    -d @"$TEMP_JSON" \
    --max-time 30)

rm -f "$TEMP_JSON"

if [ "$HTTP_CODE" = "200" ]; then
    success "Connexion réussie ! (HTTP $HTTP_CODE)"
    echo ""
    success "Fish.Audio est opérationnel et prêt à l'emploi ! 🎉"
elif [ "$HTTP_CODE" = "401" ]; then
    error "Erreur d'authentification (HTTP $HTTP_CODE)"
    echo ""
    echo "Votre clé API semble invalide ou expirée."
    echo "Relancez la configuration : ./configure_fish_audio.sh"
elif [ "$HTTP_CODE" = "429" ]; then
    error "Limite de taux dépassée (HTTP $HTTP_CODE)"
    echo ""
    echo "Attendez quelques minutes avant de réessayer."
elif [ "$HTTP_CODE" = "000" ]; then
    error "Impossible de contacter Fish.Audio"
    echo ""
    echo "Vérifiez votre connexion internet."
else
    error "Code de réponse inattendu: HTTP $HTTP_CODE"
fi
echo ""

# 3. Vérifier la configuration du projet
info "3. Vérification de la configuration du projet..."

PROJECT_JSON="/Volumes/J3THext/Audiobookforge/audio/Projects/nomduvent1/project.json"

if [ -f "$PROJECT_JSON" ]; then
    success "Fichier projet trouvé"
    
    # Vérifier fallbackToRemote
    if grep -q '"fallbackToRemote"[[:space:]]*:[[:space:]]*true' "$PROJECT_JSON"; then
        success "Fallback to Remote: activé ✓"
    else
        error "Fallback to Remote: désactivé ✗"
        echo "   Activez-le dans l'interface AudiobookForge"
    fi
    
    # Vérifier l'audio de référence
    if grep -q '"referenceAudioPath"' "$PROJECT_JSON"; then
        success "Audio de référence: configuré ✓"
    else
        error "Audio de référence: manquant ✗"
        echo "   Ajoutez un audio de référence dans l'étape 3 - Voix"
    fi
    
    # Vérifier la transcription
    if grep -q '"referenceText"' "$PROJECT_JSON"; then
        success "Transcription de référence: configurée ✓"
    else
        error "Transcription de référence: manquante ✗"
        echo "   Ajoutez la transcription dans l'étape 3 - Voix"
    fi
else
    error "Projet 'nomduvent1' non trouvé"
    echo "   Créez d'abord un projet dans AudiobookForge"
fi
echo ""

# 4. Vérifier le dossier models (local)
info "4. Vérification du modèle local MLX..."

MODELS_DIR="/Volumes/J3THext/Audiobookforge/models"

if [ -d "$MODELS_DIR" ] && [ "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
    success "Modèle local trouvé"
    echo "   L'app utilisera le modèle local en priorité"
else
    error "Aucun modèle local trouvé"
    echo "   L'app basculera automatiquement vers Fish.Audio ✓"
fi
echo ""

# Résumé
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ "$HTTP_CODE" = "200" ]; then
    success "Tout est prêt pour générer avec Fish.Audio ! 🚀"
    echo ""
    echo "Prochaines étapes :"
    echo "  1. Lancez AudiobookForge : ./Lancer\\ AudiobookForge.command"
    echo "  2. Ouvrez le projet 'nomduvent1'"
    echo "  3. Allez à l'étape 4 - Génération"
    echo "  4. Sélectionnez un chapitre et cliquez sur 'Générer'"
    echo ""
    info "Coût estimé pour tout le livre : ~18 USD"
else
    error "Configuration incomplète ou problème de connexion"
    echo ""
    echo "Actions recommandées :"
    echo "  1. Vérifiez votre connexion internet"
    echo "  2. Relancez : ./configure_fish_audio.sh"
    echo "  3. Consultez : GUIDE_FISH_AUDIO.md"
fi
echo ""
