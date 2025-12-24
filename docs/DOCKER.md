# Guide Docker - MariaDB 11.8

Ce guide détaille l'installation, la configuration et l'utilisation de l'environnement Docker pour tester les procédures stockées de duplication de données.

---

## Table des matières

1. [Prérequis](#pr%C3%A9requis)
2. [Installation de Docker](#installation-de-docker)
3. [Configuration de MariaDB](#configuration-de-mariadb)
4. [Démarrage](#d%C3%A9marrage)
5. [Connexion à la base](#connexion-%C3%A0-la-base)
6. [Commandes utiles](#commandes-utiles)
7. [Arrêt et nettoyage](#arr%C3%AAt-et-nettoyage)
8. [Dépannage](#d%C3%A9pannage)

---

## Prérequis

| Composant | Version minimale | Vérification |
|-----------|------------------|--------------|
| Docker | 20.10+ | `docker --version` |
| Docker Compose | 2.0+ | `docker compose version` |
| RAM disponible | 2 Go+ | - |
| Espace disque | 5 Go+ | - |

---

## Installation de Docker

### Linux (Ubuntu/Debian)

```bash
# Mise à jour des paquets
sudo apt update

# Installation des dépendances
sudo apt install -y ca-certificates curl gnupg lsb-release

# Ajout de la clé GPG officielle Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Ajout du dépôt Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Installation de Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Ajout de l'utilisateur au groupe docker (évite sudo)
sudo usermod -aG docker $USER

# Redémarrer la session pour appliquer les changements
```

### Windows

1. Télécharger [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Lancer l'installateur
3. Redémarrer l'ordinateur
4. Lancer Docker Desktop

### macOS

1. Télécharger [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Glisser Docker dans Applications
3. Lancer Docker Desktop

---

## Configuration de MariaDB

### Structure des fichiers Docker

```
docker/
├── docker-compose.yml     # Orchestration des services
├── Dockerfile             # Image personnalisée (optionnel)
├── config/
│   └── my.cnf             # Configuration MariaDB
└── init/
    └── 00_init.sh         # Script d'initialisation
```

### Variables d'environnement

| Variable | Valeur par défaut | Description |
|----------|-------------------|-------------|
| `MARIADB_ROOT_PASSWORD` | `duplication_root_2025` | Mot de passe root |
| `MARIADB_DATABASE` | `duplication_db` | Base de données |
| `MARIADB_USER` | `duplication_user` | Utilisateur applicatif |
| `MARIADB_PASSWORD` | `duplication_pass_2025` | Mot de passe utilisateur |

### Personnalisation

Pour modifier les paramètres, éditez le fichier `docker-compose.yml` :

```yaml
environment:
  MARIADB_ROOT_PASSWORD: votre_mot_de_passe_securise
  MARIADB_DATABASE: ma_base
  MARIADB_USER: mon_utilisateur
  MARIADB_PASSWORD: mon_mot_de_passe
```

---

## Démarrage

### Méthode 1 : Avec le script fourni

```bash
# Rendre le script exécutable
chmod +x scripts/start.sh

# Démarrer
./scripts/start.sh
```

### Méthode 2 : Avec Docker Compose

```bash
# Se placer dans le dossier docker
cd docker/

# Démarrer en arrière-plan
docker-compose up -d

# Voir les logs en temps réel
docker-compose logs -f
```

### Vérification du démarrage

```bash
# Vérifier que le conteneur est en cours d'exécution
docker ps

# Résultat attendu :
# CONTAINER ID   IMAGE         STATUS         PORTS                    NAMES
# abc123...      mariadb:11.8  Up 2 minutes   0.0.0.0:3306->3306/tcp   mariadb-duplication
```

---

## Connexion à la base

### Via Docker (recommandé)

```bash
# Connexion en tant que root
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025

# Connexion en tant qu'utilisateur
docker exec -it mariadb-duplication mysql -u duplication_user -pduplication_pass_2025 duplication_db
```

### Via un client externe

Paramètres de connexion :

| Paramètre | Valeur |
|-----------|--------|
| Hôte | `localhost` ou `127.0.0.1` |
| Port | `3306` |
| Utilisateur | `root` ou `duplication_user` |
| Mot de passe | Voir variables d'environnement |
| Base de données | `duplication_db` |

### Clients recommandés

- **DBeaver** : [https://dbeaver.io/](https://dbeaver.io/)
- **HeidiSQL** : [https://www.heidisql.com/](https://www.heidisql.com/)
- **MySQL Workbench** : [https://www.mysql.com/products/workbench/](https://www.mysql.com/products/workbench/)

---

## Commandes utiles

### Gestion du conteneur

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Redémarrer
docker-compose restart

# Voir les logs
docker-compose logs -f

# Voir les logs des 100 dernières lignes
docker-compose logs --tail 100
```

### Exécution de scripts SQL

```bash
# Exécuter un fichier SQL
docker exec -i mariadb-duplication mysql -u root -pduplication_root_2025 duplication_db < mon_script.sql

# Exécuter une requête directe
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025 -e "SHOW DATABASES;"
```

### Sauvegarde et restauration

```bash
# Sauvegarde
docker exec mariadb-duplication mysqldump -u root -pduplication_root_2025 duplication_db > backup.sql

# Restauration
docker exec -i mariadb-duplication mysql -u root -pduplication_root_2025 duplication_db < backup.sql
```

### Inspection

```bash
# Voir les processus en cours
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025 -e "SHOW PROCESSLIST;"

# Voir les variables
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025 -e "SHOW VARIABLES LIKE '%buffer%';"

# Voir le statut
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025 -e "SHOW STATUS;"
```

---

## Arrêt et nettoyage

### Arrêt simple (conserve les données)

```bash
# Arrêter le conteneur
docker-compose down

# Les données sont conservées dans le volume nommé
```

### Arrêt complet (supprime tout)

```bash
# Arrêter et supprimer le conteneur + les volumes
docker-compose down -v

# Supprimer aussi les images
docker-compose down -v --rmi all
```

### Script de nettoyage complet

```bash
# Utiliser le script fourni
chmod +x scripts/clean.sh
./scripts/clean.sh
```

### Nettoyage manuel approfondi

```bash
# Arrêter tous les conteneurs du projet
docker-compose down -v --rmi all

# Supprimer le volume nommé si encore présent
docker volume rm mariadb-duplication-data 2>/dev/null

# Supprimer le réseau si encore présent
docker network rm mariadb-duplication-network 2>/dev/null

# Nettoyer les ressources Docker inutilisées
docker system prune -f
```

---

## Dépannage

### Le conteneur ne démarre pas

```bash
# Vérifier les logs
docker-compose logs mariadb

# Erreurs courantes :
# - Port 3306 déjà utilisé : changer le port dans docker-compose.yml
# - Permissions sur les volumes : vérifier les droits
```

### Impossible de se connecter

```bash
# Vérifier que le conteneur est en cours d'exécution
docker ps

# Vérifier la santé du service
docker inspect mariadb-duplication | grep -A 10 "Health"

# Tester la connexion réseau
telnet localhost 3306
```

### Erreur "Access denied"

```bash
# Vérifier le mot de passe
docker-compose exec mariadb mysql -u root -p

# Réinitialiser le mot de passe root
docker-compose exec mariadb mysql -u root -pduplication_root_2025 -e "ALTER USER 'root'@'%' IDENTIFIED BY 'nouveau_mot_de_passe';"
```

### Performance lente

1. Augmenter les ressources dans `my.cnf` :
   - `innodb_buffer_pool_size` : 50-70% de la RAM disponible
   - `tmp_table_size` et `max_heap_table_size` : augmenter si beaucoup de tables temporaires

2. Vérifier les requêtes lentes :
   ```bash
   docker exec -it mariadb-duplication cat /var/lib/mysql/slow.log
   ```

---

## Ressources

- [Documentation officielle MariaDB 11.8](https://mariadb.com/kb/en/mariadb-11-8/)
- [Documentation Docker](https://docs.docker.com/)
- [Image Docker MariaDB](https://hub.docker.com/_/mariadb)

---

**Auteur :** Nicolas DEOUX
**Contact :** NDXDev@gmail.com
