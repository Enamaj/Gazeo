#!/usr/bin/env bash
# ==============================================================================
# Script de compilation release pour Google Play Store (App Bundle AAB obfusqué)
# Commande officielle GAZEO :
# flutter build appbundle --release --obfuscate --split-debug-info=build/debug_info
# ==============================================================================

set -e

echo "================================================================="
echo "📦 GAZEO — Compilation de l'Android App Bundle (AAB) Release"
echo "  Mode        : Release"
echo "  Obfuscation : Activée (R8 + Dart Symbol Obfuscation)"
echo "  Debug Info  : build/debug_info"
echo "================================================================="

mkdir -p build/debug_info

flutter build appbundle \
    --release \
    --obfuscate \
    --split-debug-info=build/debug_info

echo ""
echo "================================================================="
echo "✅ Compilation terminée avec succès !"
echo "Fichier généré : build/app/outputs/bundle/release/app-release.aab"
echo "Symboles de débogage (à conserver pour Play Console) : build/debug_info"
echo "================================================================="

