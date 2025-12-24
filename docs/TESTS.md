# Guide des Tests

Ce guide explique comment exécuter et interpréter les tests des procédures de duplication.

---

## Table des matières

1. [Introduction](#introduction)
2. [Prérequis](#pr%C3%A9requis)
3. [Exécution des tests](#ex%C3%A9cution)
4. [Interprétation des résultats](#r%C3%A9sultats)
5. [Tests de performance](#performance)
6. [Création de nouveaux tests](#cr%C3%A9ation-de-tests)

---

## Introduction

Les tests permettent de valider le bon fonctionnement des procédures de duplication :

- **Tests unitaires** : Chaque procédure est testée individuellement
- **Tests d'intégration** : Duplication complète d'un projet
- **Tests de validation** : Vérification de l'intégrité des données
- **Tests de performance** : Mesure des temps d'exécution

---

## Prérequis

1. MariaDB 11.8 en cours d'exécution
2. Base de données `duplication_db` créée
3. Schéma et procédures installés

```bash
# Vérifier que MariaDB est en cours d'exécution
docker ps | grep mariadb-duplication

# Se connecter
docker exec -it mariadb-duplication mysql -u root -pduplication_root_2025
```

---

## Exécution

### Méthode 1 : Via Docker (recommandée)

```bash
# Se placer dans le répertoire du projet
cd mariadb-duplication-donnees

# Exécuter les tests
docker exec -i mariadb-duplication mysql -u root -pduplication_root_2025 < sql/tests/test_duplication.sql
```

### Méthode 2 : Via un client MySQL

```bash
# Connexion directe
mysql -h localhost -P 3306 -u root -pduplication_root_2025 duplication_db < sql/tests/test_duplication.sql
```

### Méthode 3 : Interactif

```sql
-- Se connecter à MariaDB
mysql -u root -p

-- Utiliser la base
USE duplication_db;

-- Charger le fichier de tests
SOURCE /chemin/vers/sql/tests/test_duplication.sql;
```

---

## Résultats

### Format des résultats

Chaque test affiche un résultat au format suivant :

```
+----------+----------------------------------+----------------------------------------+
| Resultat | Procedure_Testee                 | Description                            |
+----------+----------------------------------+----------------------------------------+
| PASS     | SP_DupliquerLignesCommande       | Lignes dupliquées avec succès          |
| PASS     | SP_DupliquerCommande             | Nouvelle commande ID: 42               |
| FAIL     | SP_ValiderDuplication            | ERREUR: Nombre d'éléments différent    |
+----------+----------------------------------+----------------------------------------+
```

### Interprétation

| Résultat | Signification |
|----------|---------------|
| `PASS` | Le test a réussi |
| `FAIL` | Le test a échoué, vérifier la description |

### Exemple de sortie complète

```
========================================
  PRÉPARATION DES DONNÉES DE TEST
========================================

Projet de test créé avec ID: 2312
Version de test créée avec ID: 4900
Clients de test créés avec IDs: 150, 151
Commandes de test créées avec IDs: 200, 201
Lignes de commande de test créées

========================================
  TEST 1: Duplication des lignes
========================================

+----------+------------------------------+--------------------------------+
| Resultat | Procedure_Testee             | Description                    |
+----------+------------------------------+--------------------------------+
| PASS     | SP_DupliquerLignesCommande   | Lignes dupliquées avec succès  |
+----------+------------------------------+--------------------------------+

+---------------+-------------+--------------+
| Lignes_Source | Lignes_Dest | Verification |
+---------------+-------------+--------------+
|             3 |           3 | OK           |
+---------------+-------------+--------------+

========================================
  TEST 2: Duplication d'une commande
========================================

+----------+----------------------+-------------------------+
| Resultat | Procedure_Testee     | Description             |
+----------+----------------------+-------------------------+
| PASS     | SP_DupliquerCommande | Nouvelle commande ID: 3 |
+----------+----------------------+-------------------------+

... (autres tests) ...

========================================
  RÉSUMÉ DES TESTS
========================================

+----------------------+------------------+--------+--------+
| TypeOperation        | NombreOperations | Succes | Echecs |
+----------------------+------------------+--------+--------+
| DUPLICATION_CLIENT   |                1 |      1 |      0 |
| DUPLICATION_COMMANDE |                3 |      3 |      0 |
| DUPLICATION_PROJET   |                1 |      1 |      0 |
| DUPLICATION_VERSION  |                1 |      1 |      0 |
+----------------------+------------------+--------+--------+

========================================
  FIN DES TESTS
========================================
```

---

## Performance

### Mesure du temps d'exécution

Vous pouvez mesurer le temps d'exécution avec :

```sql
-- Activer le profiling
SET profiling = 1;

-- Exécuter la duplication
CALL SP_DupliquerProjet(1, 'Test Performance', 1, @succes, @id);

-- Afficher les temps
SHOW PROFILES;

-- Détails du dernier profil
SHOW PROFILE FOR QUERY 1;
```

### Test de charge

```sql
-- Créer plusieurs projets à dupliquer
DELIMITER $$
CREATE PROCEDURE SP_TestCharge(IN p_Iterations INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE v_Start DATETIME(6);
    DECLARE v_End DATETIME(6);
    DECLARE v_Succes INT;
    DECLARE v_Id INT;

    SET v_Start = NOW(6);

    WHILE i < p_Iterations DO
        CALL SP_DupliquerProjet(
            1,
            CONCAT('Projet Charge ', i),
            1,
            v_Succes,
            v_Id
        );
        SET i = i + 1;
    END WHILE;

    SET v_End = NOW(6);

    SELECT
        p_Iterations AS Iterations,
        TIMESTAMPDIFF(MICROSECOND, v_Start, v_End) / 1000000 AS Duree_Secondes,
        p_Iterations / (TIMESTAMPDIFF(MICROSECOND, v_Start, v_End) / 1000000) AS Projets_Par_Seconde;
END$$
DELIMITER ;

-- Exécuter 10 duplications
CALL SP_TestCharge(10);
```

### Benchmarks de référence

| Opération | Volume | Temps moyen |
|-----------|--------|-------------|
| Duplication 1 client | 5 commandes, 20 lignes | < 100 ms |
| Duplication 1 version | 10 clients, 50 commandes | < 500 ms |
| Duplication 1 projet | 3 versions, 30 clients | < 2 s |

---

## Création de tests

### Template de test

```sql
-- =============================================================================
-- TEST : [Nom du test]
-- =============================================================================
-- Description : [Ce que le test vérifie]
-- Prérequis   : [Données nécessaires]
-- =============================================================================

-- Préparation
SET @test_id = NULL;
SET @test_erreur = NULL;

-- Exécution
CALL [Nom_Procedure]([paramètres], @test_id, @test_erreur);

-- Vérification
SELECT
    CASE
        WHEN @test_erreur = 0 AND @test_id > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS Resultat,
    '[Nom_Procedure]' AS Procedure_Testee,
    CASE
        WHEN @test_erreur = 0 THEN CONCAT('Succès, ID: ', @test_id)
        ELSE 'Échec de la procédure'
    END AS Description;

-- Validation supplémentaire (optionnel)
CALL SP_ValiderDuplication('[TYPE]', @source_id, @test_id, @valide, @msg);

SELECT
    CASE WHEN @valide = 1 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'Validation' AS Procedure_Testee,
    @msg AS Description;
```

### Bonnes pratiques

1. **Isoler les tests** : Chaque test doit être indépendant
2. **Données de test** : Créer des données spécifiques pour chaque test
3. **Nettoyage** : Prévoir la suppression des données de test
4. **Messages clairs** : Descriptions explicites en cas d'échec

### Exemple de test personnalisé

```sql
-- Test de duplication avec code client personnalisé
SELECT '========================================' AS '';
SELECT '  TEST PERSONNALISÉ: Code client' AS '';
SELECT '========================================' AS '';

-- Préparation : Créer un client de test
INSERT INTO tb_Client (fkVersion, Code, RaisonSociale, Actif, DateCrea, ParQui)
VALUES (1, 'CLI-ORIG', 'Client Original', 1, NOW(), 'TEST');

SET @client_orig = LAST_INSERT_ID();

-- Exécution : Dupliquer avec un code personnalisé
CALL SP_DupliquerClient(
    @client_orig,
    1,
    'CLI-PERSO-999',    -- Code personnalisé
    @client_copie,
    @erreur
);

-- Vérification du code
SELECT
    CASE
        WHEN Code = 'CLI-PERSO-999' THEN 'PASS'
        ELSE 'FAIL'
    END AS Resultat,
    'Code client personnalisé' AS Test,
    Code AS Code_Obtenu
FROM tb_Client
WHERE id = @client_copie;

-- Nettoyage
DELETE FROM tb_Client WHERE id IN (@client_orig, @client_copie);
```

---

## Dépannage des tests

### Test échoue : "Commande source introuvable"

**Cause** : L'ID de commande n'existe pas
**Solution** : Vérifier que les données de test sont créées

```sql
SELECT * FROM tb_Commande WHERE id = @commande_test_id;
```

### Test échoue : "Nombre d'éléments différent"

**Cause** : La duplication n'a pas copié tous les éléments
**Solution** : Vérifier les logs

```sql
SELECT * FROM tb_Logs
WHERE TypeOperation LIKE 'DUPLICATION%'
ORDER BY id DESC LIMIT 10;
```

### Test échoue : "Timeout"

**Cause** : Transaction trop longue
**Solution** : Augmenter le timeout

```sql
SET @@session.innodb_lock_wait_timeout = 300;
```

---

**Auteur :** Nicolas DEOUX
**Contact :** NDXDev@gmail.com
