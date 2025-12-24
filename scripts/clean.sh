#!/bin/bash
# =============================================================================
# Script de nettoyage complet - MariaDB 11.8 Duplication
# =============================================================================
#
# Ce script supprime TOUT : conteneurs, volumes, images et réseaux.
# ATTENTION : Toutes les données seront perdues !
#
# Utilisation :
#   ./clean.sh
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

echo -e "${RED}"
echo "=============================================="
echo " ATTENTION : Nettoyage COMPLET"
echo "=============================================="
echo ""
echo " Cette opération va SUPPRIMER :"
echo "   - Le conteneur MariaDB"
echo "   - Le volume de données"
echo "   - Les images Docker"
echo "   - Le réseau Docker"
echo ""
echo " TOUTES LES DONNÉES SERONT PERDUES !"
echo ""
echo "=============================================="
echo -e "${NC}"

# Demander confirmation
read -p "Êtes-vous sûr de vouloir continuer ? (oui/non) : " CONFIRM

if [ "$CONFIRM" != "oui" ]; then
    echo -e "${YELLOW}[INFO] Opération annulée${NC}"
    exit 0
fi

# Se placer dans le répertoire Docker
cd "$DOCKER_DIR"

echo -e "${YELLOW}[INFO] Arrêt et suppression des conteneurs...${NC}"

# Arrêter et supprimer tout
docker compose down -v --rmi all 2>/dev/null || true

echo -e "${YELLOW}[INFO] Suppression du volume nommé...${NC}"

# Supprimer le volume s'il existe encore
docker volume rm mariadb-duplication-data 2>/dev/null || true

echo -e "${YELLOW}[INFO] Suppression du réseau...${NC}"

# Supprimer le réseau s'il existe encore
docker network rm mariadb-duplication-network 2>/dev/null || true

echo -e "${YELLOW}[INFO] Nettoyage des ressources Docker orphelines...${NC}"

# Nettoyer les ressources inutilisées
docker system prune -f 2>/dev/null || true

echo -e "${GREEN}"
echo "=============================================="
echo " Nettoyage terminé avec succès"
echo "=============================================="
echo ""
echo " Tous les conteneurs, volumes et images"
echo " liés à ce projet ont été supprimés."
echo ""
echo " Pour recréer l'environnement : ./start.sh"
echo "=============================================="
echo -e "${NC}"
