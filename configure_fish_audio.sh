#!/bin/bash

# Script de configuration Fish.Audio pour AudiobookForge
# Usage: ./configure_fish_audio.sh

set -e

echo "🐟 Configuration Fish.Audio pour AudiobookForge"
echo "================================================"
echo ""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher les messages
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier si une clé API existe déjà
check_existing_key() {
    info "Vérification de la clé API existante..."
    if security find-generic-password -s "fish_audio_api_key" -w 2>/dev/null; then
        success "Une clé API Fish.Audio est déjà configurée !"
        echo ""
        read -p "Voulez-vous la remplacer ? (o/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            info "Configuration annulée. Clé existante conservée."
            exit 0
        fi
        # Supprimer l'ancienne clé
        security delete-generic-password -s "fish_audio_api_key" 2>/dev/null || true
        info "Ancienne clé supprimée."
    else
        info "Aucune clé API trouvée. Configuration nécessaire."
    fi
    echo ""
}

# Demander la clé API à l'utilisateur
prompt_api_key() {
    echo "📝 Veuillez entrer votre clé API Fish.Audio"
    echo "   (Format: fk-xxxxx...)"
    echo ""
    echo "   Si vous n'avez pas de clé API :"
    echo "   1. Créez un compte sur https://fish.audio"
    echo "   2. Allez dans Settings → API Keys"
    echo "   3. Créez une nouvelle clé API"
    echo ""
    read -p "Clé API Fish.Audio: " -r API_KEY
    echo ""
    
    # Vérifier que la clé n'est pas vide
    if [ -z "$API_KEY" ]; then
        error "Clé API vide. Configuration annulée."
        exit 1
    fi
    
    # Vérifier le format de la clé (commence par fk-)
    if [[ ! $API_KEY =~ ^fk- ]]; then
        warning "La clé ne commence pas par 'fk-'. Êtes-vous sûr qu'elle est correcte ?"
        read -p "Continuer quand même ? (o/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            error "Configuration annulée."
            exit 1
        fi
    fi
}

# Ajouter la clé dans le Keychain
add_to_keychain() {
    info "Ajout de la clé API dans le Keychain macOS..."
    
    if security add-generic-password \
        -a "AudiobookForge" \
        -s "fish_audio_api_key" \
        -w "$API_KEY" \
        -U 2>/dev/null; then
        success "Clé API ajoutée avec succès dans le Keychain !"
    else
        error "Échec de l'ajout de la clé dans le Keychain."
        exit 1
    fi
    echo ""
}

# Tester la connexion à Fish.Audio
test_connection() {
    info "Test de connexion à Fish.Audio..."
    echo ""
    
    # Créer un fichier temporaire pour la requête
    TEMP_JSON=$(mktemp)
    cat > "$TEMP_JSON" <<EOF
{
    "text": "Test de connexion AudiobookForge.",
    "format": "wav"
}
EOF
    
    # Faire une requête de test
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://api.fish.audio/v1/tts" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -H "model: s2-pro" \
        -d @"$TEMP_JSON" \
        --max-time 30)
    
    rm -f "$TEMP_JSON"
    
    if [ "$HTTP_CODE" = "200" ]; then
        success "Connexion réussie ! Fish.Audio est opérationnel."
        echo ""
        info "Votre clé API est valide et fonctionnelle."
        return 0
    elif [ "$HTTP_CODE" = "401" ]; then
        error "Erreur d'authentification (401)"
        echo ""
        warning "Votre clé API semble invalide ou expirée."
        echo "   Vérifiez votre clé sur https://fish.audio"
        return 1
    elif [ "$HTTP_CODE" = "429" ]; then
        warning "Limite de taux dépassée (429)"
        echo ""
        info "Votre clé API est valide mais vous avez atteint la limite."
        info "Attendez quelques minutes avant de réessayer."
        return 0
    elif [ "$HTTP_CODE" = "000" ]; then
        error "Impossible de contacter Fish.Audio"
        echo ""
        warning "Vérifiez votre connexion internet."
        return 1
    else
        warning "Code de réponse inattendu: $HTTP_CODE"
        echo ""
        info "La clé a été sauvegardée mais le test a échoué."
        info "Vérifiez votre connexion et réessayez plus tard."
        return 1
    fi
}

# Afficher les informations de coût
show_pricing_info() {
    echo ""
    echo "💰 Informations de tarification Fish.Audio"
    echo "=========================================="
    echo ""
    echo "Modèle S2-Pro :"
    echo "  • Coût : ~15 USD / million de caractères"
    echo "  • Qualité : Professionnelle"
    echo "  • Voice cloning : Oui (zero-shot)"
    echo ""
    echo "Estimation pour votre projet 'nomduvent1' :"
    echo "  • Caractères : ~1.2 million"
    echo "  • Coût estimé : ~18 USD"
    echo ""
    info "Conseil : Testez d'abord sur 1-2 chapitres avant de générer tout le livre."
    echo ""
}

# Afficher les prochaines étapes
show_next_steps() {
    echo ""
    echo "🎯 Prochaines étapes"
    echo "===================="
    echo ""
    echo "1. Lancer AudiobookForge :"
    echo "   ./Lancer\\ AudiobookForge.command"
    echo ""
    echo "2. Ouvrir votre projet 'nomduvent1'"
    echo ""
    echo "3. Aller à l'étape 4 - Génération"
    echo ""
    echo "4. Sélectionner un chapitre et cliquer sur 'Générer'"
    echo ""
    echo "5. L'app basculera automatiquement vers Fish.Audio"
    echo ""
    info "Consultez GUIDE_FISH_AUDIO.md pour plus de détails."
    echo ""
}

# Programme principal
main() {
    check_existing_key
    prompt_api_key
    add_to_keychain
    
    if test_connection; then
        show_pricing_info
        show_next_steps
        success "Configuration terminée avec succès ! 🎉"
    else
        echo ""
        warning "La clé a été sauvegardée mais le test de connexion a échoué."
        echo ""
        echo "Vous pouvez :"
        echo "  1. Vérifier votre connexion internet"
        echo "  2. Vérifier votre clé sur https://fish.audio"
        echo "  3. Relancer ce script pour mettre à jour la clé"
        echo ""
        info "La clé est sauvegardée et sera utilisée par AudiobookForge."
    fi
}

# Lancer le script
main
