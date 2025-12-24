# Documentation des Procédures Stockées

Ce document détaille toutes les procédures stockées disponibles pour la duplication de données dans MariaDB 11.8.

---

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Procédures utilitaires](#proc%C3%A9dures-utilitaires)
3. [Procédures de duplication](#proc%C3%A9dures-de-duplication)
4. [Procédures de validation](#proc%C3%A9dures-de-validation)
5. [Exemples d'utilisation](#exemples-dutilisation)
6. [Bonnes pratiques](#bonnes-pratiques)

---

## Vue d'ensemble

### Hiérarchie des procédures

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
```

### Dépendances

| Procédure | Dépend de |
|-----------|-----------|
| `SP_DupliquerProjet` | `SP_DupliquerVersion`, `SP_GenererNumero`, `SP_LogOperation` |
| `SP_DupliquerVersion` | `SP_DupliquerClient`, `SP_GenererNumero`, `SP_LogOperation` |
| `SP_DupliquerClient` | `SP_DupliquerCommande`, `SP_GenererNumero`, `SP_LogOperation` |
| `SP_DupliquerCommande` | `SP_DupliquerLignesCommande`, `SP_GenererNumero`, `SP_LogOperation` |
| `SP_DupliquerLignesCommande` | - |

---

## Procédures utilitaires

### SP_GenererNumero

Génère un nouveau numéro séquentiel pour un type d'entité donné.

#### Signature

```sql
CALL SP_GenererNumero(
    IN  p_TypeCompteur    VARCHAR(50),  -- Type: PROJET, VERSION, CLIENT, COMMANDE
    IN  p_InTransaction   INT,          -- 1 si dans une transaction, 0 sinon
    OUT p_NouveauNumero   INT           -- Numéro généré
);
```

#### Exemple

```sql
-- Générer un nouveau numéro de projet
CALL SP_GenererNumero('PROJET', 0, @num);
SELECT @num;  -- Affiche: 1, 2, 3, ...
```

#### Comportement

- Incrémente atomiquement le compteur dans `tb_Compteur`
- Utilise `INSERT ... ON DUPLICATE KEY UPDATE` pour la sécurité concurrentielle
- Retourne -1 en cas d'erreur

---

### SP_GetEqMapping

Récupère l'ID mappé (nouveau) à partir d'un ID source (ancien) dans une table temporaire.

#### Signature

```sql
CALL SP_GetEqMapping(
    IN  p_TableMapping  VARCHAR(100),  -- Nom de la table de mapping
    IN  p_IdSource      INT,           -- ID source à rechercher
    OUT p_IdDestination INT,           -- ID destination trouvé
    OUT p_Succes        INT            -- 1 si trouvé, 0 sinon
);
```

#### Exemple

```sql
-- Rechercher le nouvel ID d'un client
CALL SP_GetEqMapping('EqClient', 123, @nouveau_id, @succes);
IF @succes = 1 THEN
    SELECT CONCAT('Nouvel ID: ', @nouveau_id);
END IF;
```

---

### SP_LogOperation

Enregistre une opération dans le journal des duplications.

#### Signature

```sql
CALL SP_LogOperation(
    IN p_TypeOperation  VARCHAR(50),   -- Type d'opération
    IN p_TableSource    VARCHAR(100),  -- Nom de la table
    IN p_IdSource       INT,           -- ID source
    IN p_IdDestination  INT,           -- ID destination
    IN p_Message        TEXT,          -- Message descriptif
    IN p_Succes         INT,           -- 1 = succès, 0 = échec
    IN p_ParQui         VARCHAR(100)   -- Utilisateur
);
```

#### Exemple

```sql
CALL SP_LogOperation(
    'DUPLICATION_CLIENT',
    'tb_Client',
    1,
    42,
    'Client dupliqué avec succès',
    1,
    'admin'
);
```

---

### SP_CreerTableMapping

Crée une table temporaire en mémoire pour stocker les correspondances d'IDs.

#### Signature

```sql
CALL SP_CreerTableMapping(
    IN p_NomTable VARCHAR(100)  -- Nom de la table à créer
);
```

#### Exemple

```sql
-- Créer une table de mapping pour les clients
CALL SP_CreerTableMapping('EqClient');

-- Insérer une correspondance
INSERT INTO EqClient (idPrev, idNext) VALUES (1, 42);

-- À la fin, nettoyer
DROP TEMPORARY TABLE IF EXISTS EqClient;
```

---

## Procédures de duplication

### SP_DupliquerLignesCommande

Duplique les lignes d'une commande vers une nouvelle commande.

#### Signature

```sql
CALL SP_DupliquerLignesCommande(
    IN  p_CommandeSource INT,  -- ID de la commande source
    IN  p_CommandeDest   INT,  -- ID de la commande destination
    OUT p_Erreur         INT   -- 0 = succès, 1 = erreur
);
```

#### Comportement

1. Parcourt toutes les lignes de la commande source via un curseur
2. Renumérote les lignes séquentiellement (1, 2, 3, ...)
3. Copie toutes les données (référence, désignation, quantité, prix, etc.)
4. Conserve les montants calculés

#### Exemple

```sql
CALL SP_DupliquerLignesCommande(100, 200, @err);
IF @err = 0 THEN
    SELECT 'Lignes copiées avec succès';
END IF;
```

---

### SP_DupliquerCommande

Duplique une commande complète avec toutes ses lignes.

#### Signature

```sql
CALL SP_DupliquerCommande(
    IN  p_CommandeSource INT,  -- ID de la commande source
    IN  p_ClientDest     INT,  -- ID du client destination
    OUT p_CommandeDest   INT,  -- ID de la nouvelle commande (OUT)
    OUT p_Erreur         INT   -- 0 = succès, 1 = erreur
);
```

#### Comportement

1. Récupère les métadonnées de la commande source
2. Génère un nouveau numéro de commande via `SP_GenererNumero`
3. Crée la nouvelle commande avec le statut "EN_ATTENTE"
4. Appelle `SP_DupliquerLignesCommande` pour les lignes
5. Recalcule les montants HT et TTC
6. Journalise l'opération

#### Exemple

```sql
CALL SP_DupliquerCommande(100, 42, @nouvelle_cmd, @err);
SELECT CONCAT('Nouvelle commande: ', @nouvelle_cmd);
```

---

### SP_DupliquerClient

Duplique un client avec toutes ses commandes.

#### Signature

```sql
CALL SP_DupliquerClient(
    IN  p_ClientSource INT,        -- ID du client source
    IN  p_VersionDest  INT,        -- ID de la version destination
    IN  p_NouveauCode  VARCHAR(20),-- Nouveau code (NULL = auto-généré)
    OUT p_ClientDest   INT,        -- ID du nouveau client (OUT)
    OUT p_Erreur       INT         -- 0 = succès, 1 = erreur
);
```

#### Comportement

1. Crée une table temporaire `EqCommande` pour le mapping
2. Copie les données du client (raison sociale, adresse, etc.)
3. Génère un nouveau code client si non fourni
4. Parcourt et duplique chaque commande du client
5. Stocke les correspondances dans `EqCommande`
6. Nettoie la table temporaire à la fin

#### Exemple

```sql
-- Duplication avec code auto-généré
CALL SP_DupliquerClient(1, 5, NULL, @nouveau_client, @err);

-- Duplication avec code personnalisé
CALL SP_DupliquerClient(1, 5, 'CLI-SPECIAL', @nouveau_client, @err);
```

---

### SP_DupliquerVersion

Duplique une version complète avec tous ses clients et commandes.

#### Signature

```sql
CALL SP_DupliquerVersion(
    IN  p_VersionSource  INT,          -- ID de la version source
    IN  p_ProjetDest     INT,          -- ID du projet destination
    IN  p_NouveauLibelle VARCHAR(200), -- Libellé (NULL = auto-généré)
    IN  p_IdUtilisateur  INT,          -- ID de l'utilisateur
    OUT p_VersionDest    INT,          -- ID de la nouvelle version (OUT)
    OUT p_Succes         INT           -- 1 = succès, 0 = échec
);
```

#### Comportement

1. Démarre une transaction
2. Crée une table temporaire `EqClient` pour le mapping
3. Génère le numéro de version suivant pour le projet
4. Crée la nouvelle version avec le statut "BROUILLON"
5. Parcourt et duplique chaque client
6. COMMIT si tout est OK, ROLLBACK sinon
7. Journalise l'opération

#### Exemple

```sql
CALL SP_DupliquerVersion(1, 1, 'Version 2.0', 1, @nouvelle_version, @succes);
IF @succes = 1 THEN
    SELECT CONCAT('Nouvelle version créée: ', @nouvelle_version);
END IF;
```

---

### SP_DupliquerProjet

Duplique un projet complet avec toutes ses versions, clients et commandes.

#### Signature

```sql
CALL SP_DupliquerProjet(
    IN  p_ProjetSource   INT,          -- ID du projet source
    IN  p_NouveauLibelle VARCHAR(200), -- Libellé du nouveau projet
    IN  p_IdUtilisateur  INT,          -- ID de l'utilisateur
    OUT p_Succes         INT,          -- 1 = succès, 0 = échec
    OUT p_ProjetDest     INT           -- ID du nouveau projet (OUT)
);
```

#### Comportement

1. Augmente le timeout de transaction (120s)
2. Démarre une transaction principale
3. Crée une table temporaire `EqVersion` pour le mapping
4. Génère un nouveau numéro de projet
5. Crée le nouveau projet avec le statut "ACTIF"
6. Parcourt et duplique chaque version
7. COMMIT global si tout est OK
8. Journalise l'opération (succès ou échec)

#### Exemple

```sql
CALL SP_DupliquerProjet(1, 'Mon Nouveau Projet', 1, @succes, @nouveau_projet);
IF @succes = 1 THEN
    SELECT CONCAT('Projet dupliqué avec succès, ID: ', @nouveau_projet);
ELSE
    SELECT 'Erreur lors de la duplication';
END IF;
```

---

## Procédures de validation

### SP_ValiderDuplication

Valide qu'une duplication a été effectuée correctement.

#### Signature

```sql
CALL SP_ValiderDuplication(
    IN  p_TypeEntite VARCHAR(50),  -- PROJET, VERSION, CLIENT, COMMANDE
    IN  p_IdSource   INT,          -- ID source
    IN  p_IdDest     INT,          -- ID destination
    OUT p_Valide     INT,          -- 1 = valide, 0 = invalide
    OUT p_Message    VARCHAR(500)  -- Message descriptif
);
```

#### Exemple

```sql
CALL SP_ValiderDuplication('CLIENT', 1, 42, @valide, @msg);
SELECT @msg;
-- Affiche: "Duplication valide. Commandes: source=5, destination=5"
```

---

### SP_ComparerEntites

Compare les données entre une entité source et sa copie.

#### Signature

```sql
CALL SP_ComparerEntites(
    IN p_Table    VARCHAR(100),  -- Nom de la table
    IN p_IdSource INT,           -- ID de l'enregistrement source
    IN p_IdDest   INT            -- ID de l'enregistrement destination
);
```

#### Exemple

```sql
-- Comparer un client source et sa copie
CALL SP_ComparerEntites('tb_Client', 1, 42);

-- Résultat :
-- +------------+----------+--------+------------------------+
-- | TableName  | IdSource | IdDest | Resultat               |
-- +------------+----------+--------+------------------------+
-- | tb_Client  |        1 |     42 | Comparaison effectuée  |
-- +------------+----------+--------+------------------------+
```

---

### SP_AfficherStatsDuplication

Affiche les statistiques des duplications effectuées.

#### Signature

```sql
CALL SP_AfficherStatsDuplication();
```

#### Exemple de sortie

```
+---------------------+------------------+--------+--------+
| TypeOperation       | NombreOperations | Succes | Echecs |
+---------------------+------------------+--------+--------+
| DUPLICATION_CLIENT  |               10 |     10 |      0 |
| DUPLICATION_COMMANDE|               25 |     24 |      1 |
| DUPLICATION_PROJET  |                3 |      3 |      0 |
| DUPLICATION_VERSION |                6 |      6 |      0 |
+---------------------+------------------+--------+--------+
```

---

## Exemples d'utilisation

### Duplication simple d'un client

```sql
-- Dupliquer le client ID=1 vers la version ID=5
CALL SP_DupliquerClient(1, 5, NULL, @nouveau_client, @erreur);

-- Vérifier le résultat
IF @erreur = 0 THEN
    SELECT CONCAT('Client créé avec succès, ID: ', @nouveau_client);

    -- Valider la duplication
    CALL SP_ValiderDuplication('CLIENT', 1, @nouveau_client, @valide, @msg);
    SELECT @msg;
ELSE
    SELECT 'Erreur lors de la duplication';
END IF;
```

### Duplication d'un projet vers un nouveau prévis

```sql
-- Dupliquer le projet complet
CALL SP_DupliquerProjet(
    1,                      -- Projet source
    'Copie pour Analyse',   -- Nouveau libellé
    1,                      -- ID utilisateur
    @succes,                -- OUT: succès
    @nouveau_projet         -- OUT: ID du nouveau projet
);

-- Afficher le résultat
IF @succes = 1 THEN
    SELECT p.NumProjet, p.Libelle, COUNT(v.id) AS NbVersions
    FROM tb_Projet p
    LEFT JOIN tb_Version v ON p.id = v.fkProjet
    WHERE p.id = @nouveau_projet
    GROUP BY p.id;
END IF;
```

---

## Bonnes pratiques

### Gestion des transactions

```sql
-- Les procédures de haut niveau gèrent leur propre transaction
-- NE PAS les appeler dans une transaction externe

-- INCORRECT :
START TRANSACTION;
CALL SP_DupliquerProjet(...);  -- Erreur potentielle
COMMIT;

-- CORRECT :
CALL SP_DupliquerProjet(...);  -- Gère sa propre transaction
```

### Gestion des erreurs

```sql
-- Toujours vérifier les paramètres OUT
CALL SP_DupliquerClient(1, 5, NULL, @id, @err);

IF @err = 1 THEN
    -- Consulter les logs pour plus de détails
    SELECT * FROM tb_Logs
    WHERE TableSource = 'tb_Client'
    ORDER BY id DESC LIMIT 1;
END IF;
```

### Performance

```sql
-- Pour les duplications massives, augmenter les buffers
SET SESSION innodb_buffer_pool_size = 512M;
SET SESSION tmp_table_size = 128M;
SET SESSION max_heap_table_size = 128M;

-- Désactiver les vérifications temporairement
SET FOREIGN_KEY_CHECKS = 0;
CALL SP_DupliquerProjet(...);
SET FOREIGN_KEY_CHECKS = 1;
```

---

**Auteur :** Nicolas DEOUX
**Contact :** NDXDev@gmail.com
