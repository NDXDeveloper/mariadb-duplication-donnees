#!/bin/bash
# =============================================================================
# Script d'arrêt - MariaDB 11.8 Duplication
# =============================================================================
#
# Ce script arrête proprement l'environnement Docker MariaDB.
# Les données sont conservées dans le volume Docker.
#
# Utilisation :
#   ./stop.sh
#
# Auteur : Nicolas DEOUX (NDXDev@gmail.com)
# =============================================================================

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_DIR="$PROJECT_DIR/docker"

echo -e "${BLUE}"
echo "=============================================="
echo " Arrêt MariaDB 11.8 - Duplication"
echo "=============================================="
echo -e "${NC}"

# Se placer dans le répertoire Docker
cd "$DOCKER_DIR"

echo -e "${YELLOW}[INFO] Arrêt des conteneurs...${NC}"

# Arrêter les conteneurs
docker compose down

echo -e "${GREEN}"
echo "=============================================="
echo " MariaDB arrêté avec succès"
echo "=============================================="
echo ""
echo " Les données sont conservées dans le volume."
echo ""
echo " Pour redémarrer : ./start.sh"
echo " Pour tout supprimer : ./clean.sh"
echo "=============================================="
echo -e "${NC}"
