#!/usr/bin/env bash
# ==============================================================================
# Script d'exécution des tests de charge GAZEO avec Locust
# Simule 5 000 utilisateurs simultanés à Yaoundé
# Objectifs : médiane < 500ms, erreurs < 1%
# ==============================================================================

set -e

HOST="${1:-http://127.0.0.1:8000}"
USERS="${2:-5000}"
SPAWN_RATE="${3:-100}"
DURATION="${4:-5m}"

echo "================================================================="
echo "⚡ GAZEO — Lancement du Test de Charge Locust"
echo "  Cible       : $HOST"
echo "  Utilisateurs: $USERS"
echo "  Spawn Rate  : $SPAWN_RATE users/s"
echo "  Durée       : $DURATION"
echo "================================================================="

# Vérification présence de locust
if ! command -v locust &> /dev/null && [ ! -f "venv/bin/locust" ]; then
    echo "❌ Locust n'est pas installé. Lancez : pip install locust"
    exit 1
fi

LOCUST_BIN="locust"
if [ -f "venv/bin/locust" ]; then
    LOCUST_BIN="venv/bin/locust"
fi

# Exécution du test de charge en mode headless
$LOCUST_BIN -f locustfile.py \
    --host="$HOST" \
    --headless \
    --users="$USERS" \
    --spawn-rate="$SPAWN_RATE" \
    --run-time="$DURATION" \
    --csv="locust_report" \
    --html="locust_report.html"

echo "================================================================="
echo "✅ Test de charge terminé avec succès !"
echo "Rapports générés : locust_report.html et locust_report_*.csv"
echo "================================================================="

