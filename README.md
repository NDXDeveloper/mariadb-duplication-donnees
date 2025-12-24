# Duplication de Données MariaDB

```
    ____              ___            __  _
   / __ \__  ______  / (_)________ _/ /_(_)___  ____
  / / / / / / / __ \/ / / ___/ __ `/ __/ / __ \/ __ \
 / /_/ / /_/ / /_/ / / / /__/ /_/ / /_/ / /_/ / / / /
/_____/\__,_/ .___/_/_/\___/\__,_/\__/_/\____/_/ /_/
    __  __  /_/          _       ____  ____
   / /_/ /_  ___        | |     / / / / __ \
  / __/ __ \/ _ \       | | /| / / /_/ / / /
 / /_/ / / /  __/       | |/ |/ / __  / /_/
 \__/_/ /_/\_/          |__/|__/_/ /_/_____/

   MariaDB 11.8 | Procédures Stockées | Docker
```

---

## Bienvenue !

Ce dépôt est votre **guide complet** pour maîtriser la **duplication de données** dans MariaDB 11.8 via des **procédures stockées**.

Que vous soyez développeur, DBA, ou simplement curieux d'apprendre les bonnes pratiques SQL, vous êtes au bon endroit !

---

## Pourquoi ce projet ?

La duplication de données est un enjeu **critique** dans les applications métier :

| Cas d'usage | Description |
|-------------|-------------|
| **Versioning** | Créer des versions de travail sans affecter les données de production |
| **Templates** | Dupliquer des modèles pour accélérer la saisie |
| **Archivage** | Conserver des snapshots de données à un instant T |
| **Tests** | Générer des jeux de données réalistes pour les tests |
| **Migration** | Transférer des structures complexes entre projets |

---

## Ce que vous allez apprendre

```
+------------------------------------------+
|                                          |
|   1. Architecture de duplication         |
|      hiérarchique                        |
|                                          |
|   2. Gestion des transactions            |
|      (COMMIT/ROLLBACK)                   |
|                                          |
|   3. Tables temporaires pour             |
|      le mapping des IDs                  |
|                                          |
|   4. Curseurs SQL pour parcourir         |
|      les enregistrements                 |
|                                          |
|   5. Gestion d'erreurs avec              |
|      HANDLER et RESIGNAL                 |
|                                          |
|   6. Appels récursifs entre              |
|      procédures stockées                 |
|                                          |
+------------------------------------------+
```

---

## Démarrage rapide

### Prérequis

- Docker et Docker Compose installés
- Un terminal (bash, zsh, PowerShell...)

### Installation en 3 commandes

```bash
# 1. Cloner le dépôt
git clone https://github.com/votre-username/mariadb-duplication-donnees.git
cd mariadb-duplication-donnees

# 2. Lancer MariaDB 11.8 via Docker
docker-compose up -d

# 3. Se connecter et explorer
docker exec -it mariadb-duplication mysql -u root -p
```

Le mot de passe par défaut est : `duplication_root_2025`

---

## Structure du projet

```
mariadb-duplication-donnees/
│
├── README.md                    # Ce fichier
├── SOMMAIRE.md                  # Table des matières détaillée
├── LICENSE                      # Licence MIT
│
├── docker/
│   ├── Dockerfile               # Image Docker personnalisée
│   ├── docker-compose.yml       # Orchestration des services
│   └── init/                    # Scripts d'initialisation
│
├── docs/
│   ├── DOCKER.md                # Guide Docker complet
│   ├── PROCEDURES.md            # Documentation des procédures
│   ├── ARCHITECTURE.md          # Architecture de duplication
│   └── TESTS.md                 # Guide des tests
│
├── sql/
│   ├── schemas/                 # Schémas de base de données
│   │   └── 00_init_schema.sql   # Structure initiale
│   │
│   ├── procedures/              # Procédures stockées
│   │   ├── 01_utils.sql         # Utilitaires
│   │   ├── 02_duplication.sql   # Procédures de duplication
│   │   └── 03_validation.sql    # Procédures de validation
│   │
│   └── tests/                   # Scripts de test
│       └── test_duplication.sql # Tests de duplication
│
└── scripts/
    ├── start.sh                 # Démarrer l'environnement
    ├── stop.sh                  # Arrêter proprement
    └── clean.sh                 # Nettoyer complètement
```

---

## Exemples de procédures incluses

### Duplication simple

```sql
-- Dupliquer un client avec toutes ses commandes
CALL SP_DupliquerClient(
    @id_client_source,      -- ID du client à dupliquer
    @id_client_destination, -- ID du nouveau client (OUT)
    @succes                 -- 1 = succès, 0 = échec (OUT)
);
```

### Duplication hiérarchique

```sql
-- Dupliquer un projet complet (versions, bâtiments, plans, objets...)
CALL SP_DupliquerProjet(
    @id_projet_source,      -- ID du projet source
    'Nouveau Projet 2025',  -- Libellé du nouveau projet
    @id_user,               -- ID de l'utilisateur
    @succes,                -- Succès de l'opération (OUT)
    @id_nouveau_projet      -- ID du nouveau projet (OUT)
);
```

---

## Points forts techniques

### Gestion des transactions

```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    ROLLBACK;    -- Annuler en cas d'erreur
    RESIGNAL;    -- Propager l'erreur
END;

START TRANSACTION;
-- ... opérations de duplication ...
COMMIT;
```

### Tables temporaires pour le mapping

```sql
-- Table de correspondance ancien ID -> nouvel ID
CREATE TEMPORARY TABLE EqMapping (
    id INT AUTO_INCREMENT PRIMARY KEY,
    idPrev INT,    -- Ancien ID
    idNext INT     -- Nouvel ID
) ENGINE=MEMORY;
```

### Curseurs pour le parcours des données

```sql
DECLARE cursor_items CURSOR FOR
    SELECT id, libelle, fk_parent
    FROM ma_table
    WHERE fk_parent = @parent_id;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

OPEN cursor_items;
read_loop: LOOP
    FETCH cursor_items INTO v_id, v_libelle, v_fk_parent;
    IF done THEN
        LEAVE read_loop;
    END IF;
    -- Traitement...
END LOOP;
CLOSE cursor_items;
```

---

## Documentation complète

| Document | Description |
|----------|-------------|
| [SOMMAIRE.md](SOMMAIRE.md) | Table des matières complète |
| [docs/DOCKER.md](docs/DOCKER.md) | Installation et configuration Docker |
| [docs/PROCEDURES.md](docs/PROCEDURES.md) | Référence des procédures stockées |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture de duplication |
| [docs/TESTS.md](docs/TESTS.md) | Guide pour exécuter les tests |

---

## Commandes Docker utiles

```bash
# Démarrer MariaDB
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Se connecter à MariaDB
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025

# Arrêter MariaDB
docker-compose down

# Supprimer TOUT (conteneurs + volumes)
docker-compose down -v --rmi all
```

---

## Compatibilité

| Composant | Version |
|-----------|---------|
| MariaDB | 11.8+ |
| Docker | 20.10+ |
| Docker Compose | 2.0+ |

---

## Auteur

**Nicolas DEOUX**

- Email : NDXDev@gmail.com
- LinkedIn : [nicolas-deoux](https://www.linkedin.com/in/nicolas-deoux-ab295980/)

---

## Licence

Ce projet est sous licence **MIT** - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   Bonne exploration et bonne duplication !                    ║
║                                                               ║
║   N'hésitez pas à vous inspirer de ces exemples pour          ║
║   vos propres projets.                                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```
