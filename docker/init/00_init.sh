#!/bin/bash
# =============================================================================
# Script d'initialisation - MariaDB 11.8 Duplication
# =============================================================================
#
# Ce script est exécuté automatiquement au premier démarrage du conteneur.
# Il configure l'environnement et prépare la base de données.
#
# Auteur : Nicolas DEOUX (NDXDev@gmail.com)
# =============================================================================

echo "=============================================="
echo " Initialisation MariaDB - Duplication"
echo "=============================================="
echo ""
echo " Date     : $(date '+%Y-%m-%d %H:%M:%S')"
echo " Version  : MariaDB 11.8"
echo " Base     : duplication_db"
echo ""
echo "=============================================="

# Attendre que MariaDB soit prêt
sleep 5

echo "[INFO] Environnement prêt pour les procédures stockées"
echo "[INFO] Les scripts SQL vont être exécutés..."
