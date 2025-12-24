-- =============================================================================
-- Tests de Duplication - MariaDB 11.8
-- =============================================================================
--
-- Ce fichier contient les tests pour valider le bon fonctionnement des
-- procédures de duplication de données.
--
-- Exécution :
--   mysql -u root -p duplication_db < test_duplication.sql
--
-- Ou via Docker :
--   docker exec -i mariadb-duplication mysql -u root -p < test_duplication.sql
--
-- Auteur : Nicolas DEOUX (NDXDev@gmail.com)
-- Date   : Décembre 2025
-- =============================================================================

USE duplication_db;

-- =============================================================================
-- SECTION 1 : Préparation des données de test
-- =============================================================================

SELECT '========================================' AS '';
SELECT '  PRÉPARATION DES DONNÉES DE TEST' AS '';
SELECT '========================================' AS '';

-- Création d'un projet de test
INSERT INTO tb_Projet (NumProjet, Libelle, Description, fkCreateur, Statut, DateDebut, Budget, DateCrea, ParQui)
VALUES (9999, 'Projet Test Duplication', 'Projet créé pour tester les procédures de duplication', 1, 'ACTIF', CURDATE(), 50000.00, NOW(), 'TEST');

SET @projet_test_id = LAST_INSERT_ID();
SELECT CONCAT('Projet de test créé avec ID: ', @projet_test_id) AS Info;

-- Création d'une version de test
INSERT INTO tb_Version (fkProjet, NumVersion, Libelle, Description, Statut, fkUtilisateur, DateCrea, ParQui)
VALUES (@projet_test_id, 1, 'Version 1.0', 'Première version de test', 'BROUILLON', 1, NOW(), 'TEST');

SET @version_test_id = LAST_INSERT_ID();
SELECT CONCAT('Version de test créée avec ID: ', @version_test_id) AS Info;

-- Création de clients de test
INSERT INTO tb_Client (fkVersion, Code, RaisonSociale, Adresse, CodePostal, Ville, Pays, Telephone, Email, Contact, Actif, DateCrea, ParQui)
VALUES
    (@version_test_id, 'CLI-TEST-001', 'Entreprise Alpha', '123 Rue Test', '75001', 'Paris', 'France', '0100000001', 'alpha@test.com', 'Jean Dupont', 1, NOW(), 'TEST'),
    (@version_test_id, 'CLI-TEST-002', 'Entreprise Beta', '456 Avenue Demo', '69001', 'Lyon', 'France', '0200000002', 'beta@test.com', 'Marie Martin', 1, NOW(), 'TEST');

SET @client1_id = LAST_INSERT_ID();
SET @client2_id = @client1_id + 1;
SELECT CONCAT('Clients de test créés avec IDs: ', @client1_id, ', ', @client2_id) AS Info;

-- Création de commandes de test pour le client 1
INSERT INTO tb_Commande (fkClient, NumCommande, DateCommande, DateLivraison, Statut, TauxTVA, Remise, Notes, DateCrea, ParQui)
VALUES
    (@client1_id, 'CMD-TEST-001', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'EN_ATTENTE', 20.00, 5.00, 'Commande de test 1', NOW(), 'TEST'),
    (@client1_id, 'CMD-TEST-002', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 45 DAY), 'VALIDEE', 20.00, 0.00, 'Commande de test 2', NOW(), 'TEST');

SET @commande1_id = LAST_INSERT_ID();
SET @commande2_id = @commande1_id + 1;
SELECT CONCAT('Commandes de test créées avec IDs: ', @commande1_id, ', ', @commande2_id) AS Info;

-- Création de lignes de commande pour la commande 1
INSERT INTO tb_LigneCommande (fkCommande, NumLigne, Reference, Designation, Quantite, Unite, PrixUnitaire, Remise, MontantHT, DateCrea, ParQui)
VALUES
    (@commande1_id, 1, 'REF-001', 'Article de test A', 10.000, 'U', 25.0000, 0.00, 250.00, NOW(), 'TEST'),
    (@commande1_id, 2, 'REF-002', 'Article de test B', 5.000, 'U', 50.0000, 10.00, 225.00, NOW(), 'TEST'),
    (@commande1_id, 3, 'REF-003', 'Article de test C', 2.500, 'KG', 100.0000, 0.00, 250.00, NOW(), 'TEST');

-- Mise à jour des montants de la commande
UPDATE tb_Commande SET
    MontantHT = 725.00,
    MontantTTC = 725.00 * 1.20
WHERE id = @commande1_id;

SELECT 'Lignes de commande de test créées' AS Info;

-- =============================================================================
-- SECTION 2 : Tests de duplication des lignes de commande
-- =============================================================================

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  TEST 1: Duplication des lignes' AS '';
SELECT '========================================' AS '';

-- Créer une commande destination vide
INSERT INTO tb_Commande (fkClient, NumCommande, DateCommande, Statut, TauxTVA, DateCrea, ParQui)
VALUES (@client1_id, 'CMD-DEST-LIGNES', CURDATE(), 'EN_ATTENTE', 20.00, NOW(), 'TEST');

SET @commande_dest_lignes = LAST_INSERT_ID();

-- Exécuter la duplication des lignes
CALL SP_DupliquerLignesCommande(@commande1_id, @commande_dest_lignes, @erreur_lignes);

SELECT
    CASE WHEN @erreur_lignes = 0 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_DupliquerLignesCommande' AS Procedure_Testee,
    CASE WHEN @erreur_lignes = 0
         THEN 'Lignes dupliquées avec succès'
         ELSE 'Erreur lors de la duplication des lignes'
    END AS Description;

-- Vérifier le nombre de lignes
SELECT
    (SELECT COUNT(*) FROM tb_LigneCommande WHERE fkCommande = @commande1_id) AS Lignes_Source,
    (SELECT COUNT(*) FROM tb_LigneCommande WHERE fkCommande = @commande_dest_lignes) AS Lignes_Dest,
    CASE WHEN (SELECT COUNT(*) FROM tb_LigneCommande WHERE fkCommande = @commande1_id) =
              (SELECT COUNT(*) FROM tb_LigneCommande WHERE fkCommande = @commande_dest_lignes)
         THEN 'OK' ELSE 'ERREUR'
    END AS Verification;

-- =============================================================================
-- SECTION 3 : Tests de duplication d'une commande
-- =============================================================================

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  TEST 2: Duplication d''une commande' AS '';
SELECT '========================================' AS '';

-- Exécuter la duplication de la commande
CALL SP_DupliquerCommande(@commande1_id, @client1_id, @commande_dupliquee, @erreur_commande);

SELECT
    CASE WHEN @erreur_commande = 0 AND @commande_dupliquee > 0 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_DupliquerCommande' AS Procedure_Testee,
    CONCAT('Nouvelle commande ID: ', COALESCE(@commande_dupliquee, 'N/A')) AS Description;

-- Validation
CALL SP_ValiderDuplication('COMMANDE', @commande1_id, @commande_dupliquee, @valide, @message);

SELECT
    CASE WHEN @valide = 1 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_ValiderDuplication (COMMANDE)' AS Procedure_Testee,
    @message AS Description;

-- =============================================================================
-- SECTION 4 : Tests de duplication d'un client
-- =============================================================================

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  TEST 3: Duplication d''un client' AS '';
SELECT '========================================' AS '';

-- Exécuter la duplication du client
CALL SP_DupliquerClient(@client1_id, @version_test_id, 'CLI-COPIE-001', @client_duplique, @erreur_client);

SELECT
    CASE WHEN @erreur_client = 0 AND @client_duplique > 0 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_DupliquerClient' AS Procedure_Testee,
    CONCAT('Nouveau client ID: ', COALESCE(@client_duplique, 'N/A')) AS Description;

-- Validation
CALL SP_ValiderDuplication('CLIENT', @client1_id, @client_duplique, @valide, @message);

SELECT
    CASE WHEN @valide = 1 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_ValiderDuplication (CLIENT)' AS Procedure_Testee,
    @message AS Description;

-- =============================================================================
-- SECTION 5 : Tests de duplication d'une version
-- =============================================================================

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  TEST 4: Duplication d''une version' AS '';
SELECT '========================================' AS '';

-- Exécuter la duplication de la version
CALL SP_DupliquerVersion(@version_test_id, @projet_test_id, 'Version 2.0 (Copie)', 1, @version_dupliquee, @succes_version);

SELECT
    CASE WHEN @succes_version = 1 AND @version_dupliquee > 0 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_DupliquerVersion' AS Procedure_Testee,
    CONCAT('Nouvelle version ID: ', COALESCE(@version_dupliquee, 'N/A')) AS Description;

-- Validation
CALL SP_ValiderDuplication('VERSION', @version_test_id, @version_dupliquee, @valide, @message);

SELECT
    CASE WHEN @valide = 1 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_ValiderDuplication (VERSION)' AS Procedure_Testee,
    @message AS Description;

-- =============================================================================
-- SECTION 6 : Tests de duplication d'un projet complet
-- =============================================================================

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  TEST 5: Duplication d''un projet' AS '';
SELECT '========================================' AS '';

-- Exécuter la duplication du projet complet
CALL SP_DupliquerProjet(@projet_test_id, 'Projet Dupliqué Test', 1, @succes_projet, @projet_duplique);

SELECT
    CASE WHEN @succes_projet = 1 AND @projet_duplique > 0 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_DupliquerProjet' AS Procedure_Testee,
    CONCAT('Nouveau projet ID: ', COALESCE(@projet_duplique, 'N/A')) AS Description;

-- Validation
CALL SP_ValiderDuplication('PROJET', @projet_test_id, @projet_duplique, @valide, @message);

SELECT
    CASE WHEN @valide = 1 THEN 'PASS' ELSE 'FAIL' END AS Resultat,
    'SP_ValiderDuplication (PROJET)' AS Procedure_Testee,
    @message AS Description;

-- =============================================================================
-- SECTION 7 : Résumé des tests
-- =============================================================================

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  RÉSUMÉ DES TESTS' AS '';
SELECT '========================================' AS '';

-- Afficher les statistiques de duplication
CALL SP_AfficherStatsDuplication();

-- Afficher le contenu du journal
SELECT '' AS '';
SELECT 'Journal des opérations:' AS '';
SELECT
    TypeOperation,
    TableSource,
    IdSource,
    IdDestination,
    LEFT(Message, 60) AS Message,
    CASE WHEN Succes = 1 THEN 'OK' ELSE 'ERREUR' END AS Statut,
    DATE_FORMAT(DateOperation, '%Y-%m-%d %H:%i:%s') AS Date
FROM tb_Logs
WHERE DateOperation >= DATE_SUB(NOW(), INTERVAL 1 HOUR)
ORDER BY id DESC
LIMIT 20;

-- =============================================================================
-- SECTION 8 : Nettoyage (optionnel)
-- =============================================================================

-- Décommenter les lignes suivantes pour nettoyer les données de test
/*
SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  NETTOYAGE DES DONNÉES DE TEST' AS '';
SELECT '========================================' AS '';

-- Supprimer le projet dupliqué
DELETE FROM tb_Projet WHERE id = @projet_duplique;

-- Supprimer le projet de test original
DELETE FROM tb_Projet WHERE id = @projet_test_id;

-- Supprimer les entrées de compteur générées
UPDATE tb_Compteur SET ValeurActuelle = 0 WHERE TypeCompteur IN ('PROJET', 'VERSION', 'CLIENT', 'COMMANDE');

-- Supprimer les logs de test
DELETE FROM tb_Logs WHERE ParQui LIKE 'SP_%' AND DateOperation >= DATE_SUB(NOW(), INTERVAL 1 HOUR);

SELECT 'Données de test nettoyées' AS Info;
*/

SELECT '' AS '';
SELECT '========================================' AS '';
SELECT '  FIN DES TESTS' AS '';
SELECT '========================================' AS '';
SELECT 'Tous les tests ont été exécutés. Vérifiez les résultats ci-dessus.' AS Info;
