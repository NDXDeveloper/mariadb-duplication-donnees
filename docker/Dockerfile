# =============================================================================
# Dockerfile - Image personnalisée MariaDB 11.8 pour Duplication de Données
# =============================================================================
#
# Cette image étend l'image officielle MariaDB 11.8 avec :
#   - Configuration optimisée pour les procédures stockées
#   - Scripts d'initialisation pré-chargés
#   - Outils de débogage SQL
#
# Construction :
#   docker build -t mariadb-duplication:11.8 .
#
# Utilisation :
#   docker run -d -p 3306:3306 --name mariadb-test mariadb-duplication:11.8
#
# Auteur : Nicolas DEOUX (NDXDev@gmail.com)
# =============================================================================

# Image de base : MariaDB 11.8 officielle
FROM mariadb:11.8

# Métadonnées de l'image
LABEL maintainer="Nicolas DEOUX <NDXDev@gmail.com>"
LABEL description="MariaDB 11.8 optimisé pour la duplication de données"
LABEL version="1.0.0"

# Variables d'environnement par défaut
ENV MARIADB_ROOT_PASSWORD=duplication_root_2025 \
    MARIADB_DATABASE=duplication_db \
    MARIADB_USER=duplication_user \
    MARIADB_PASSWORD=duplication_pass_2025 \
    TZ=Europe/Paris

# Copie de la configuration personnalisée
COPY config/my.cnf /etc/mysql/conf.d/custom.cnf

# Copie des scripts d'initialisation
# Ces scripts seront exécutés automatiquement au premier démarrage
# dans l'ordre alphabétique
COPY init/ /docker-entrypoint-initdb.d/

# Permissions sur les scripts
RUN chmod 644 /etc/mysql/conf.d/custom.cnf && \
    chmod 755 /docker-entrypoint-initdb.d/*.sql 2>/dev/null || true && \
    chmod 755 /docker-entrypoint-initdb.d/*.sh 2>/dev/null || true

# Port exposé
EXPOSE 3306

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD healthcheck.sh --connect --innodb_initialized || exit 1

# Point d'entrée et commande par défaut
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mariadbd", \
     "--character-set-server=utf8mb4", \
     "--collation-server=utf8mb4_unicode_ci", \
     "--innodb-buffer-pool-size=256M", \
     "--max-connections=100"]
