# Table des Matières

## Duplication de Données MariaDB 11.8

---

## 1. Introduction

- [1.1 Présentation du projet](#11-présentation-du-projet)
- [1.2 Objectifs](#12-objectifs)
- [1.3 Public cible](#13-public-cible)
- [1.4 Prérequis](#14-prérequis)

---

## 2. Installation et Configuration

- [2.1 Installation de Docker](docs/DOCKER.md#installation-de-docker)
- [2.2 Configuration de MariaDB 11.8](docs/DOCKER.md#configuration-de-mariadb)
- [2.3 Démarrage de l'environnement](docs/DOCKER.md#démarrage)
- [2.4 Arrêt et nettoyage](docs/DOCKER.md#arrêt-et-nettoyage)

---

## 3. Architecture de Duplication

- [3.1 Concepts fondamentaux](docs/ARCHITECTURE.md#concepts-fondamentaux)
- [3.2 Hiérarchie des entités](docs/ARCHITECTURE.md#hiérarchie-des-entités)
- [3.3 Tables de mapping temporaires](docs/ARCHITECTURE.md#tables-de-mapping)
- [3.4 Gestion des transactions](docs/ARCHITECTURE.md#gestion-des-transactions)
- [3.5 Gestion des erreurs](docs/ARCHITECTURE.md#gestion-des-erreurs)

---

## 4. Schéma de Base de Données

- [4.1 Structure des tables](sql/schemas/00_init_schema.sql)
  - [4.1.1 Table des projets](#table-des-projets)
  - [4.1.2 Table des versions](#table-des-versions)
  - [4.1.3 Table des clients](#table-des-clients)
  - [4.1.4 Table des commandes](#table-des-commandes)
  - [4.1.5 Table des lignes de commande](#table-des-lignes)

---

## 5. Procédures Stockées

### 5.1 Procédures Utilitaires

| Procédure | Description | Documentation |
|-----------|-------------|---------------|
| `SP_GetEqMapping` | Récupère l'ID mappé | [Voir](docs/PROCEDURES.md#sp_geteqmapping) |
| `SP_CreateNumero` | Génère un nouveau numéro | [Voir](docs/PROCEDURES.md#sp_createnumero) |

### 5.2 Procédures de Duplication

| Procédure | Description | Documentation |
|-----------|-------------|---------------|
| `SP_DupliquerClient` | Duplique un client | [Voir](docs/PROCEDURES.md#sp_dupliquerclient) |
| `SP_DupliquerCommande` | Duplique une commande | [Voir](docs/PROCEDURES.md#sp_dupliquercommande) |
| `SP_DupliquerLignesCommande` | Duplique les lignes | [Voir](docs/PROCEDURES.md#sp_dupliquerlignescommande) |
| `SP_DupliquerProjet` | Duplique un projet complet | [Voir](docs/PROCEDURES.md#sp_dupliquerprojet) |
| `SP_DupliquerVersion` | Duplique une version | [Voir](docs/PROCEDURES.md#sp_dupliquerversion) |

### 5.3 Procédures de Validation

| Procédure | Description | Documentation |
|-----------|-------------|---------------|
| `SP_ValiderDuplication` | Valide une duplication | [Voir](docs/PROCEDURES.md#sp_validerduplication) |
| `SP_ComparerEntites` | Compare deux entités | [Voir](docs/PROCEDURES.md#sp_comparerentites) |

---

## 6. Guide des Tests

- [6.1 Introduction aux tests](docs/TESTS.md#introduction)
- [6.2 Exécution des tests](docs/TESTS.md#exécution)
- [6.3 Interprétation des résultats](docs/TESTS.md#résultats)
- [6.4 Tests de performance](docs/TESTS.md#performance)

---

## 7. Fichiers SQL

### 7.1 Schémas

| Fichier | Description |
|---------|-------------|
| [00_init_schema.sql](sql/schemas/00_init_schema.sql) | Structure initiale de la base |

### 7.2 Procédures

| Fichier | Description |
|---------|-------------|
| [01_utils.sql](sql/procedures/01_utils.sql) | Procédures utilitaires |
| [02_duplication.sql](sql/procedures/02_duplication.sql) | Procédures de duplication |
| [03_validation.sql](sql/procedures/03_validation.sql) | Procédures de validation |

### 7.3 Tests

| Fichier | Description |
|---------|-------------|
| [test_duplication.sql](sql/tests/test_duplication.sql) | Tests de duplication |

---

## 8. Scripts

| Script | Description |
|--------|-------------|
| [start.sh](scripts/start.sh) | Démarrer l'environnement |
| [stop.sh](scripts/stop.sh) | Arrêter proprement |
| [clean.sh](scripts/clean.sh) | Nettoyer complètement |

---

## 9. Annexes

### 9.1 Glossaire

| Terme | Définition |
|-------|------------|
| **Duplication** | Copie d'un enregistrement avec ses dépendances |
| **Mapping** | Correspondance entre ancien et nouvel ID |
| **Curseur** | Structure pour parcourir un jeu de résultats |
| **Handler** | Gestionnaire d'exceptions SQL |
| **Transaction** | Ensemble d'opérations atomiques |

### 9.2 Références

- [Documentation officielle MariaDB 11.8](https://mariadb.com/kb/en/mariadb-11-8/)
- [Documentation Docker](https://docs.docker.com/)
- [Procédures stockées MariaDB](https://mariadb.com/kb/en/stored-procedures/)

---

## 10. Historique des versions

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | Décembre 2025 | Version initiale |

---

## Navigation rapide

```
README.md ─────────────────> Introduction générale
     │
     ├── docs/
     │   ├── DOCKER.md ────> Configuration Docker
     │   ├── ARCHITECTURE.md > Architecture technique
     │   ├── PROCEDURES.md ─> Référence des procédures
     │   └── TESTS.md ─────> Guide des tests
     │
     ├── sql/
     │   ├── schemas/ ─────> Structure de la BDD
     │   ├── procedures/ ──> Code des procédures
     │   └── tests/ ───────> Scripts de test
     │
     └── scripts/ ─────────> Scripts shell utilitaires
```

---

**Auteur :** Nicolas DEOUX
**Contact :** NDXDev@gmail.com
**LinkedIn :** [nicolas-deoux](https://www.linkedin.com/in/nicolas-deoux-ab295980/)
