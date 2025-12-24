# Architecture de Duplication

Ce document explique l'architecture technique des procédures de duplication de données.

---

## Table des matières

1. [Concepts fondamentaux](#concepts-fondamentaux)
2. [Hiérarchie des entités](#hi%C3%A9rarchie-des-entit%C3%A9s)
3. [Tables de mapping](#tables-de-mapping)
4. [Gestion des transactions](#gestion-des-transactions)
5. [Gestion des erreurs](#gestion-des-erreurs)
6. [Diagrammes](#diagrammes)
7. [Schéma de la base de données](#sch%C3%A9ma-de-la-base-de-donn%C3%A9es)
   - [Table tb_Projet](#table-tb_projet)
   - [Table tb_Version](#table-tb_version)
   - [Table tb_Client](#table-tb_client)
   - [Table tb_Commande](#table-tb_commande)
   - [Table tb_LigneCommande](#table-tb_lignecommande)

---

## Concepts fondamentaux

### Duplication profonde vs superficielle

| Type | Description | Exemple |
|------|-------------|---------|
| **Superficielle** | Copie uniquement l'enregistrement principal | Dupliquer le client sans ses commandes |
| **Profonde** | Copie l'enregistrement et toutes ses dépendances | Dupliquer le client AVEC ses commandes et lignes |

Nos procédures effectuent une **duplication profonde** par défaut.

### Intégrité référentielle

Lors de la duplication, les clés étrangères (FK) doivent être mises à jour pour pointer vers les nouveaux enregistrements :

```
AVANT duplication:
  Client (id=1) -> Commande (id=100, fkClient=1)

APRÈS duplication:
  Client (id=1)  -> Commande (id=100, fkClient=1)   [Original]
  Client (id=42) -> Commande (id=200, fkClient=42)  [Copie]
```

### Atomicité

Toutes les opérations de duplication sont **atomiques** grâce aux transactions :
- Soit TOUT est copié avec succès (COMMIT)
- Soit RIEN n'est copié en cas d'erreur (ROLLBACK)

---

## Hiérarchie des entités

### Structure de données

```
tb_Projet (Niveau 0)
    │
    └── tb_Version (Niveau 1)
            │
            └── tb_Client (Niveau 2)
                    │
                    └── tb_Commande (Niveau 3)
                            │
                            └── tb_LigneCommande (Niveau 4)
```

### Relations

| Table parent | Table enfant | Type de relation |
|--------------|--------------|------------------|
| `tb_Projet` | `tb_Version` | 1:N (Un projet a plusieurs versions) |
| `tb_Version` | `tb_Client` | 1:N (Une version a plusieurs clients) |
| `tb_Client` | `tb_Commande` | 1:N (Un client a plusieurs commandes) |
| `tb_Commande` | `tb_LigneCommande` | 1:N (Une commande a plusieurs lignes) |

### Cascade de duplication

```
SP_DupliquerProjet(1)
    │
    ├── Créer nouveau tb_Projet (id=10)
    │
    └── Pour chaque version du projet 1:
            │
            ├── SP_DupliquerVersion(v.id, 10)
            │       │
            │       ├── Créer nouvelle tb_Version (id=20)
            │       │
            │       └── Pour chaque client de la version:
            │               │
            │               ├── SP_DupliquerClient(c.id, 20)
            │               │       │
            │               │       ├── Créer nouveau tb_Client (id=30)
            │               │       │
            │               │       └── Pour chaque commande du client:
            │               │               │
            │               │               └── SP_DupliquerCommande(cmd.id, 30)
            │               │                       │
            │               │                       ├── Créer nouvelle tb_Commande (id=40)
            │               │                       │
            │               │                       └── SP_DupliquerLignesCommande(...)
            │               ...
            ...
```

---

## Tables de mapping

### Principe

Les tables de mapping temporaires stockent les correspondances entre les anciens et nouveaux IDs :

```sql
CREATE TEMPORARY TABLE EqClient (
    id INT AUTO_INCREMENT PRIMARY KEY,
    idPrev INT,  -- ID de l'ancien client
    idNext INT   -- ID du nouveau client
) ENGINE=MEMORY;
```

### Exemple d'utilisation

```
Avant duplication:
┌─────────────────────────────────┐
│ tb_Client                       │
├────┬──────────────┬─────────────┤
│ id │ Code         │ fkVersion   │
├────┼──────────────┼─────────────┤
│ 1  │ CLI-001      │ 5           │
│ 2  │ CLI-002      │ 5           │
└────┴──────────────┴─────────────┘

Après duplication vers version 10:
┌─────────────────────────────────┐     ┌─────────────────────┐
│ tb_Client                       │     │ EqClient (temp)     │
├────┬──────────────┬─────────────┤     ├────┬────────┬───────┤
│ id │ Code         │ fkVersion   │     │ id │ idPrev │ idNext│
├────┼──────────────┼─────────────┤     ├────┼────────┼───────┤
│ 1  │ CLI-001      │ 5           │     │ 1  │ 1      │ 3     │
│ 2  │ CLI-002      │ 5           │     │ 2  │ 2      │ 4     │
│ 3  │ CLI-003      │ 10          │◄────┤    │        │       │
│ 4  │ CLI-004      │ 10          │◄────┤    │        │       │
└────┴──────────────┴─────────────┘     └────┴────────┴───────┘
```

### Récupération du mapping

```sql
-- Trouver le nouvel ID correspondant à l'ancien ID 1
SELECT idNext FROM EqClient WHERE idPrev = 1;
-- Résultat: 3

-- Ou via la procédure utilitaire
CALL SP_GetEqMapping('EqClient', 1, @nouvel_id, @succes);
```

### Tables de mapping utilisées

| Procédure | Table de mapping | Contenu |
|-----------|------------------|---------|
| `SP_DupliquerProjet` | `EqVersion` | Correspondance des versions |
| `SP_DupliquerVersion` | `EqClient` | Correspondance des clients |
| `SP_DupliquerClient` | `EqCommande` | Correspondance des commandes |

---

## Gestion des transactions

### Transaction principale

La procédure de plus haut niveau (`SP_DupliquerProjet`) gère une transaction globale :

```sql
START TRANSACTION;

    -- Duplication du projet
    INSERT INTO tb_Projet (...) VALUES (...);

    -- Duplication de toutes les versions (cascade)
    CALL SP_DupliquerVersion(...);
    -- qui appelle SP_DupliquerClient(...)
    -- qui appelle SP_DupliquerCommande(...)
    -- etc.

    -- Si tout OK
    COMMIT;

-- En cas d'erreur
ROLLBACK;
```

### Transactions imbriquées

MariaDB ne supporte pas les vraies transactions imbriquées, donc :

1. La transaction est démarrée au niveau le plus haut
2. Les procédures enfants travaillent DANS cette transaction
3. Le COMMIT/ROLLBACK est fait au niveau le plus haut

```
SP_DupliquerProjet    ─────────────────────────────────────►
    │ START TRANSACTION                              COMMIT
    │
    └── SP_DupliquerVersion  ─────────────────────►
            │ (pas de START TRANSACTION)
            │
            └── SP_DupliquerClient  ──────────────►
                    │ (pas de START TRANSACTION)
                    │
                    └── SP_DupliquerCommande  ────►
                            (pas de START TRANSACTION)
```

### Paramètre InTransaction

Certaines procédures utilitaires acceptent un paramètre `p_InTransaction` :

```sql
-- Appelée seule (gère sa propre transaction)
CALL SP_GenererNumero('PROJET', 0, @num);

-- Appelée dans une transaction existante (pas de nouvelle transaction)
CALL SP_GenererNumero('PROJET', 1, @num);
```

---

## Gestion des erreurs

### Handler d'exceptions

Chaque procédure définit un handler pour les exceptions SQL :

```sql
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
    ROLLBACK;           -- Annuler les modifications
    SET p_Erreur = 1;   -- Indiquer l'erreur
    RESIGNAL;           -- Propager l'exception
END;
```

### Niveaux de propagation

```
SP_DupliquerProjet
    │
    └── SP_DupliquerVersion
            │
            └── SP_DupliquerClient
                    │
                    └── SP_DupliquerCommande
                            │
                            └── SP_DupliquerLignesCommande
                                    │
                                    X ERREUR !
                                    │
                                    RESIGNAL ──────►
                                              │
                            RESIGNAL ◄────────┘
                            │
                    RESIGNAL ◄──────────────┘
                    │
            RESIGNAL ◄──────────────────────┘
            │
    ROLLBACK + Log ◄────────────────────────┘
```

### Validation des paramètres

Chaque procédure valide ses paramètres d'entrée :

```sql
-- Validation au début de la procédure
IF p_IdSource IS NULL OR p_IdSource < 1 THEN
    SET p_Erreur = 1;
    LEAVE proc_main;  -- Sortie propre
END IF;
```

### Journalisation

Toutes les opérations sont journalisées dans `tb_Logs` :

```sql
-- Succès
CALL SP_LogOperation('DUPLICATION_CLIENT', 'tb_Client', 1, 42, 'OK', 1, 'admin');

-- Échec
CALL SP_LogOperation('DUPLICATION_CLIENT', 'tb_Client', 1, -1, 'Erreur FK', 0, 'admin');
```

---

## Diagrammes

### Flux de duplication d'un projet

```
┌─────────────────────────────────────────────────────────────────┐
│                    SP_DupliquerProjet                           │
├─────────────────────────────────────────────────────────────────┤
│  1. START TRANSACTION                                           │
│  2. Créer table temporaire EqVersion                            │
│  3. Générer nouveau numéro de projet                            │
│  4. INSERT nouveau projet                                       │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ BOUCLE : Pour chaque version                              │  │
│  │   │                                                       │  │
│  │   └── CALL SP_DupliquerVersion                            │  │
│  │         │                                                 │  │
│  │         ├── Créer table temporaire EqClient               │  │
│  │         ├── INSERT nouvelle version                       │  │
│  │         │                                                 │  │
│  │         │ ┌───────────────────────────────────────────┐   │  │
│  │         │ │ BOUCLE : Pour chaque client               │   │  │
│  │         │ │   │                                       │   │  │
│  │         │ │   └── CALL SP_DupliquerClient             │   │  │
│  │         │ │         │                                 │   │  │
│  │         │ │         ├── Créer table EqCommande        │   │  │
│  │         │ │         ├── INSERT nouveau client         │   │  │
│  │         │ │         │                                 │   │  │
│  │         │ │         │ ┌───────────────────────────┐   │   │  │
│  │         │ │         │ │ BOUCLE : Pour chaque cmd  │   │   │  │
│  │         │ │         │ │   │                       │   │   │  │
│  │         │ │         │ │   └── SP_DupliquerCmd     │   │   │  │
│  │         │ │         │ │         │                 │   │   │  │
│  │         │ │         │ │         ├── INSERT cmd    │   │   │  │
│  │         │ │         │ │         │                 │   │   │  │
│  │         │ │         │ │         └── SP_DupliLignes│   │   │  │
│  │         │ │         │ └───────────────────────────┘   │   │  │
│  │         │ │         │                                 │   │  │
│  │         │ │         └── DROP EqCommande               │   │  │
│  │         │ └───────────────────────────────────────────┘   │  │
│  │         │                                                 │  │
│  │         └── DROP EqClient                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  5. COMMIT ou ROLLBACK                                          │
│  6. DROP EqVersion                                              │
│  7. Log opération                                               │
└─────────────────────────────────────────────────────────────────┘
```

### Schéma de la base de données

#### Table tb_Projet

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | INT | Clé primaire auto-incrémentée |
| `NumProjet` | VARCHAR(20) | Numéro unique du projet |
| `Libelle` | VARCHAR(200) | Libellé du projet |
| `fkCreateur` | INT | FK vers tb_Utilisateur |
| `DateCreation` | DATETIME | Date de création |

#### Table tb_Version

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | INT | Clé primaire auto-incrémentée |
| `fkProjet` | INT | FK vers tb_Projet |
| `NumVersion` | VARCHAR(20) | Numéro de la version |
| `Libelle` | VARCHAR(200) | Libellé de la version |
| `DateCreation` | DATETIME | Date de création |

#### Table tb_Client

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | INT | Clé primaire auto-incrémentée |
| `fkVersion` | INT | FK vers tb_Version |
| `Code` | VARCHAR(20) | Code unique du client |
| `RaisonSociale` | VARCHAR(200) | Raison sociale |
| `Email` | VARCHAR(100) | Email de contact |
| `Telephone` | VARCHAR(20) | Téléphone |

#### Table tb_Commande

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | INT | Clé primaire auto-incrémentée |
| `fkClient` | INT | FK vers tb_Client |
| `NumCommande` | VARCHAR(20) | Numéro unique |
| `DateCommande` | DATE | Date de la commande |
| `Statut` | VARCHAR(20) | Statut (BROUILLON, VALIDEE, etc.) |
| `MontantHT` | DECIMAL(15,2) | Montant hors taxes |

#### Table tb_LigneCommande

| Colonne | Type | Description |
|---------|------|-------------|
| `id` | INT | Clé primaire auto-incrémentée |
| `fkCommande` | INT | FK vers tb_Commande |
| `NumLigne` | INT | Numéro de la ligne |
| `Reference` | VARCHAR(50) | Référence article |
| `Designation` | VARCHAR(200) | Désignation |
| `Quantite` | DECIMAL(10,2) | Quantité |
| `PrixUnitaire` | DECIMAL(15,2) | Prix unitaire HT |

### Diagramme relationnel

```
┌─────────────────┐       ┌─────────────────┐
│   tb_Projet     │       │  tb_Utilisateur │
├─────────────────┤       ├─────────────────┤
│ id (PK)         │       │ id (PK)         │
│ NumProjet       │       │ Login           │
│ Libelle         │       │ Nom             │
│ fkCreateur (FK)─┼───────┤ ...             │
│ ...             │       └─────────────────┘
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐
│   tb_Version    │
├─────────────────┤
│ id (PK)         │
│ fkProjet (FK)   │
│ NumVersion      │
│ Libelle         │
│ ...             │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐
│   tb_Client     │
├─────────────────┤
│ id (PK)         │
│ fkVersion (FK)  │
│ Code            │
│ RaisonSociale   │
│ ...             │
└────────┬────────┘
         │ 1:N
         ▼
┌─────────────────┐
│   tb_Commande   │
├─────────────────┤
│ id (PK)         │
│ fkClient (FK)   │
│ NumCommande     │
│ DateCommande    │
│ ...             │
└────────┬────────┘
         │ 1:N
         ▼
┌──────────────────────┐
│  tb_LigneCommande    │
├──────────────────────┤
│ id (PK)              │
│ fkCommande (FK)      │
│ NumLigne             │
│ Reference            │
│ Designation          │
│ ...                  │
└──────────────────────┘
```

---

**Auteur :** Nicolas DEOUX
**Contact :** NDXDev@gmail.com
