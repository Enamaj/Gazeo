#!/usr/bin/env bash
# ==============================================================================
# Script de génération du keystore de signature Google Play Store pour GAZEO
# ATTENTION : Ne JAMAIS commiter le fichier gazeo-release.jks généré !
# Conserver une copie de sauvegarde chiffrée hors ligne (clé de signature irremplaçable).
# ==============================================================================

set -e

KEYSTORE_NAME="gazeo-release.jks"
KEY_ALIAS="gazeo"
VALIDITY_DAYS="10000"

echo "================================================================="
echo "🔑 GAZEO — Génération du Keystore Release Android"
echo "  Fichier : $KEYSTORE_NAME"
echo "  Alias   : $KEY_ALIAS"
echo "  Validité: $VALIDITY_DAYS jours (~27 ans)"
echo "================================================================="

if [ -f "$KEYSTORE_NAME" ]; then
    echo "⚠️ Le fichier $KEYSTORE_NAME existe déjà. Abandon pour éviter l'écrasement."
    exit 1
fi

keytool -genkey -v \
    -keystore "$KEYSTORE_NAME" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity "$VALIDITY_DAYS"

echo ""
echo "================================================================="
echo "✅ Keystore généré avec succès dans : $(pwd)/$KEYSTORE_NAME"
echo ""
echo "Étapes suivantes :"
echo "1. Créer le fichier 'android/key.properties' à partir de 'android/key.properties.example'"
echo "2. Renseigner les mots de passe et le chemin vers $KEYSTORE_NAME"
echo "3. Lancer le build release : ./scripts/build_release_bundle.sh"
echo "================================================================="

