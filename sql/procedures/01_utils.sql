-- =============================================================================
-- Procédures Utilitaires - Duplication de Données MariaDB 11.8
-- =============================================================================
--
-- Ce fichier contient les procédures utilitaires utilisées par les procédures
-- de duplication :
--   - Génération de numéros séquentiels
--   - Récupération des correspondances d'IDs (mapping)
--   - Journalisation des opérations
--
-- Auteur : Nicolas DEOUX (NDXDev@gmail.com)
-- Date   : Décembre 2025
-- =============================================================================

USE duplication_db;

DELIMITER $$

-- =============================================================================
-- PROCÉDURE : SP_GenererNumero
-- =============================================================================
-- Description : Génère un nouveau numéro séquentiel pour un type donné
--
-- Paramètres :
--   IN  p_TypeCompteur    : Type de compteur (PROJET, VERSION, CLIENT, COMMANDE)
--   IN  p_InTransaction   : 1 si déjà dans une transaction, 0 sinon
--   OUT p_NouveauNumero   : Le nouveau numéro généré
--
-- Retour : Le nouveau numéro via le paramètre OUT
--
-- Exemple d'utilisation :
--   CALL SP_GenererNumero('PROJET', 0, @nouveau_num);
--   SELECT @nouveau_num;
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_GenererNumero$$

CREATE PROCEDURE SP_GenererNumero(
    IN p_TypeCompteur VARCHAR(50),
    IN p_InTransaction INT,
    OUT p_NouveauNumero INT
)
SQL SECURITY INVOKER
COMMENT 'Génère un nouveau numéro séquentiel pour le type spécifié'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_ValeurActuelle INT DEFAULT 0;
    DECLARE v_Existe INT DEFAULT 0;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs
    -- -------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF p_InTransaction = 0 THEN
            ROLLBACK;
        END IF;
        SET p_NouveauNumero = -1;
        RESIGNAL;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_NouveauNumero = -1;

    -- Validation du paramètre
    IF p_TypeCompteur IS NULL OR TRIM(p_TypeCompteur) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Le type de compteur ne peut pas être vide';
    END IF;

    -- -------------------------------------------------------------------------
    -- Transaction (si pas déjà dans une transaction)
    -- -------------------------------------------------------------------------
    IF p_InTransaction = 0 THEN
        START TRANSACTION;
    END IF;

    -- -------------------------------------------------------------------------
    -- Récupération et incrémentation du compteur
    -- -------------------------------------------------------------------------

    -- Vérifier si le compteur existe
    SELECT COUNT(*), COALESCE(MAX(ValeurActuelle), 0)
    INTO v_Existe, v_ValeurActuelle
    FROM tb_Compteur
    WHERE TypeCompteur = p_TypeCompteur;

    -- Incrémenter
    SET p_NouveauNumero = v_ValeurActuelle + 1;

    -- Mettre à jour ou insérer
    INSERT INTO tb_Compteur (TypeCompteur, ValeurActuelle, DateModif)
    VALUES (p_TypeCompteur, p_NouveauNumero, NOW())
    ON DUPLICATE KEY UPDATE
        ValeurActuelle = p_NouveauNumero,
        DateModif = NOW();

    -- -------------------------------------------------------------------------
    -- Commit si transaction locale
    -- -------------------------------------------------------------------------
    IF p_InTransaction = 0 THEN
        COMMIT;
    END IF;

END$$


-- =============================================================================
-- PROCÉDURE : SP_GetEqMapping
-- =============================================================================
-- Description : Récupère l'ID mappé (nouveau) à partir de l'ID source (ancien)
--               dans une table temporaire de mapping.
--
-- Paramètres :
--   IN  p_TableMapping  : Nom de la table de mapping (EqProjet, EqVersion, etc.)
--   IN  p_IdSource      : ID source à rechercher
--   OUT p_IdDestination : ID destination trouvé (-1 si non trouvé)
--   OUT p_Succes        : 1 si trouvé, 0 sinon
--
-- Note : Cette procédure utilise des requêtes préparées (PREPARE/EXECUTE)
--        pour permettre le nom de table dynamique.
--
-- Exemple d'utilisation :
--   CALL SP_GetEqMapping('EqClient', 123, @nouveau_id, @succes);
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_GetEqMapping$$

CREATE PROCEDURE SP_GetEqMapping(
    IN p_TableMapping VARCHAR(100),
    IN p_IdSource INT,
    OUT p_IdDestination INT,
    OUT p_Succes INT
)
SQL SECURITY INVOKER
COMMENT 'Récupère l''ID mappé depuis une table temporaire de correspondance'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_IdNext INT DEFAULT -1;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs
    -- -------------------------------------------------------------------------
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_IdDestination = -1;
        SET p_Succes = 0;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_IdDestination = -1;
    SET p_Succes = 0;

    -- Validation des paramètres
    IF p_IdSource IS NULL OR p_IdSource < 0 THEN
        LEAVE proc_main;
    END IF;

    IF p_TableMapping IS NULL OR TRIM(p_TableMapping) = '' THEN
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Construction et exécution de la requête dynamique
    -- -------------------------------------------------------------------------

    -- Préparer la requête
    SET @sql_query = CONCAT(
        'SELECT idNext INTO @v_result FROM ', p_TableMapping,
        ' WHERE idPrev = ? LIMIT 1'
    );

    SET @param_id = p_IdSource;

    PREPARE stmt FROM @sql_query;
    EXECUTE stmt USING @param_id;
    DEALLOCATE PREPARE stmt;

    -- Récupérer le résultat
    IF @v_result IS NOT NULL AND @v_result > 0 THEN
        SET p_IdDestination = @v_result;
        SET p_Succes = 1;
    END IF;

END$$


-- =============================================================================
-- PROCÉDURE : SP_LogOperation
-- =============================================================================
-- Description : Enregistre une opération de duplication dans le journal
--
-- Paramètres :
--   IN p_TypeOperation  : Type d'opération (DUPLICATION_PROJET, etc.)
--   IN p_TableSource    : Nom de la table source
--   IN p_IdSource       : ID de l'enregistrement source
--   IN p_IdDestination  : ID de l'enregistrement créé
--   IN p_Message        : Message descriptif
--   IN p_Succes         : 1 pour succès, 0 pour échec
--   IN p_ParQui         : Utilisateur effectuant l'opération
--
-- Exemple d'utilisation :
--   CALL SP_LogOperation('DUPLICATION_CLIENT', 'tb_Client', 1, 2, 'Duplication OK', 1, 'admin');
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_LogOperation$$

CREATE PROCEDURE SP_LogOperation(
    IN p_TypeOperation VARCHAR(50),
    IN p_TableSource VARCHAR(100),
    IN p_IdSource INT,
    IN p_IdDestination INT,
    IN p_Message TEXT,
    IN p_Succes INT,
    IN p_ParQui VARCHAR(100)
)
SQL SECURITY INVOKER
COMMENT 'Enregistre une opération dans le journal'
BEGIN

    INSERT INTO tb_Logs (
        TypeOperation,
        TableSource,
        IdSource,
        IdDestination,
        Message,
        Succes,
        ParQui,
        DateOperation
    ) VALUES (
        p_TypeOperation,
        p_TableSource,
        p_IdSource,
        p_IdDestination,
        p_Message,
        COALESCE(p_Succes, 0),
        COALESCE(p_ParQui, 'SYSTEM'),
        NOW()
    );

END$$


-- =============================================================================
-- PROCÉDURE : SP_CreerTableMapping
-- =============================================================================
-- Description : Crée une table temporaire pour le mapping des IDs
--
-- Paramètres :
--   IN p_NomTable : Nom de la table temporaire à créer
--
-- Note : Les tables temporaires sont automatiquement supprimées
--        à la fin de la session.
--
-- Exemple d'utilisation :
--   CALL SP_CreerTableMapping('EqClient');
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_CreerTableMapping$$

CREATE PROCEDURE SP_CreerTableMapping(
    IN p_NomTable VARCHAR(100)
)
SQL SECURITY INVOKER
COMMENT 'Crée une table temporaire de mapping en mémoire'
BEGIN

    -- Suppression si existe déjà
    SET @sql_drop = CONCAT('DROP TEMPORARY TABLE IF EXISTS ', p_NomTable);
    PREPARE stmt_drop FROM @sql_drop;
    EXECUTE stmt_drop;
    DEALLOCATE PREPARE stmt_drop;

    -- Création de la table temporaire
    SET @sql_create = CONCAT(
        'CREATE TEMPORARY TABLE ', p_NomTable, ' (',
        '  id INT NOT NULL AUTO_INCREMENT,',
        '  idPrev INT DEFAULT NULL COMMENT ''ID source'',',
        '  idNext INT DEFAULT NULL COMMENT ''ID destination'',',
        '  PRIMARY KEY (id),',
        '  KEY idx_prev (idPrev)',
        ') ENGINE=MEMORY DEFAULT CHARSET=utf8mb4'
    );

    PREPARE stmt_create FROM @sql_create;
    EXECUTE stmt_create;
    DEALLOCATE PREPARE stmt_create;

END$$


-- =============================================================================
-- PROCÉDURE : SP_InsererMapping
-- =============================================================================
-- Description : Insère une correspondance dans une table de mapping
--
-- Paramètres :
--   IN p_NomTable   : Nom de la table de mapping
--   IN p_IdSource   : ID source
--   IN p_IdDest     : ID destination
--
-- Exemple d'utilisation :
--   CALL SP_InsererMapping('EqClient', 1, 42);
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_InsererMapping$$

CREATE PROCEDURE SP_InsererMapping(
    IN p_NomTable VARCHAR(100),
    IN p_IdSource INT,
    IN p_IdDest INT
)
SQL SECURITY INVOKER
COMMENT 'Insère une correspondance ID source -> ID destination'
BEGIN

    SET @sql_insert = CONCAT(
        'INSERT INTO ', p_NomTable, ' (idPrev, idNext) VALUES (?, ?)'
    );

    SET @param_prev = p_IdSource;
    SET @param_next = p_IdDest;

    PREPARE stmt FROM @sql_insert;
    EXECUTE stmt USING @param_prev, @param_next;
    DEALLOCATE PREPARE stmt;

END$$


-- =============================================================================
-- PROCÉDURE : SP_SupprimerTableMapping
-- =============================================================================
-- Description : Supprime une table temporaire de mapping
--
-- Paramètres :
--   IN p_NomTable : Nom de la table temporaire à supprimer
--
-- Exemple d'utilisation :
--   CALL SP_SupprimerTableMapping('EqClient');
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_SupprimerTableMapping$$

CREATE PROCEDURE SP_SupprimerTableMapping(
    IN p_NomTable VARCHAR(100)
)
SQL SECURITY INVOKER
COMMENT 'Supprime une table temporaire de mapping'
BEGIN

    SET @sql_drop = CONCAT('DROP TEMPORARY TABLE IF EXISTS ', p_NomTable);
    PREPARE stmt FROM @sql_drop;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END$$


DELIMITER ;

-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================

SELECT 'Procédures utilitaires créées avec succès !' AS Message;
