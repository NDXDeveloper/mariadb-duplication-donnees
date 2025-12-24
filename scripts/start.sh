#!/bin/bash
# =============================================================================
# Script de démarrage - MariaDB 11.8 Duplication
# =============================================================================
#
# Ce script démarre l'environnement Docker MariaDB et attend qu'il soit prêt.
#
# Utilisation :
#   ./start.sh
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
echo " Démarrage MariaDB 11.8 - Duplication"
echo "=============================================="
echo -e "${NC}"

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERREUR] Docker n'est pas installé${NC}"
    exit 1
fi

# Vérifier que Docker Compose est disponible
if ! docker compose version &> /dev/null; then
    echo -e "${RED}[ERREUR] Docker Compose n'est pas disponible${NC}"
    exit 1
fi

# Se placer dans le répertoire Docker
cd "$DOCKER_DIR"

echo -e "${YELLOW}[INFO] Démarrage des conteneurs...${NC}"

# Démarrer les conteneurs
docker compose up -d

echo -e "${YELLOW}[INFO] Attente du démarrage de MariaDB...${NC}"

# Attendre que MariaDB soit prêt (max 60 secondes)
COUNTER=0
MAX_WAIT=60

while [ $COUNTER -lt $MAX_WAIT ]; do
    if docker exec mariadb-duplication mysqladmin ping -h localhost -u root -pduplication_root_2025 --silent 2>/dev/null; then
        break
    fi
    echo -n "."
    sleep 1
    COUNTER=$((COUNTER + 1))
done

echo ""

if [ $COUNTER -ge $MAX_WAIT ]; then
    echo -e "${RED}[ERREUR] MariaDB n'a pas démarré dans les temps${NC}"
    docker compose logs
    exit 1
fi

echo -e "${GREEN}"
echo "=============================================="
echo " MariaDB est prêt !"
echo "=============================================="
echo ""
echo " Connexion :"
echo "   docker exec -it mariadb-duplication mysql -u root -p"
echo ""
echo " Mot de passe root : duplication_root_2025"
echo " Base de données   : duplication_db"
echo ""
echo " Pour arrêter : ./stop.sh"
echo "=============================================="
echo -e "${NC}"
