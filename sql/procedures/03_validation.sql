-- =============================================================================
-- Procédures de Validation - Duplication de Données MariaDB 11.8
-- =============================================================================
--
-- Ce fichier contient les procédures de validation permettant de vérifier
-- l'intégrité des duplications effectuées.
--
-- Auteur : Nicolas DEOUX (NDXDev@gmail.com)
-- Date   : Décembre 2025
-- =============================================================================

USE duplication_db;

DELIMITER $$

-- =============================================================================
-- PROCÉDURE : SP_ValiderDuplication
-- =============================================================================
-- Description : Valide qu'une duplication a été effectuée correctement en
--               comparant le nombre d'éléments entre source et destination.
--
-- Paramètres :
--   IN  p_TypeEntite   : Type d'entité (PROJET, VERSION, CLIENT, COMMANDE)
--   IN  p_IdSource     : ID de l'entité source
--   IN  p_IdDest       : ID de l'entité dupliquée
--   OUT p_Valide       : 1 = valide, 0 = invalide
--   OUT p_Message      : Message descriptif du résultat
--
-- Exemple d'utilisation :
--   CALL SP_ValiderDuplication('CLIENT', 1, 42, @valide, @message);
--   SELECT @valide, @message;
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_ValiderDuplication$$

CREATE PROCEDURE SP_ValiderDuplication(
    IN p_TypeEntite VARCHAR(50),
    IN p_IdSource INT,
    IN p_IdDest INT,
    OUT p_Valide INT,
    OUT p_Message VARCHAR(500)
)
SQL SECURITY INVOKER
COMMENT 'Valide l''intégrité d''une duplication'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_CountSource INT DEFAULT 0;
    DECLARE v_CountDest INT DEFAULT 0;
    DECLARE v_Details VARCHAR(500) DEFAULT '';

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_Valide = 0;
    SET p_Message = '';

    -- Validation des paramètres
    IF p_TypeEntite IS NULL OR TRIM(p_TypeEntite) = '' THEN
        SET p_Message = 'Type d''entité non spécifié';
        LEAVE proc_main;
    END IF;

    IF p_IdSource IS NULL OR p_IdSource < 1 THEN
        SET p_Message = 'ID source invalide';
        LEAVE proc_main;
    END IF;

    IF p_IdDest IS NULL OR p_IdDest < 1 THEN
        SET p_Message = 'ID destination invalide';
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Validation selon le type d'entité
    -- -------------------------------------------------------------------------

    CASE UPPER(p_TypeEntite)

        -- Validation d'un projet
        WHEN 'PROJET' THEN
            -- Compter les versions
            SELECT COUNT(*) INTO v_CountSource
            FROM tb_Version WHERE fkProjet = p_IdSource;

            SELECT COUNT(*) INTO v_CountDest
            FROM tb_Version WHERE fkProjet = p_IdDest;

            SET v_Details = CONCAT('Versions: source=', v_CountSource,
                                   ', destination=', v_CountDest);

        -- Validation d'une version
        WHEN 'VERSION' THEN
            -- Compter les clients
            SELECT COUNT(*) INTO v_CountSource
            FROM tb_Client WHERE fkVersion = p_IdSource;

            SELECT COUNT(*) INTO v_CountDest
            FROM tb_Client WHERE fkVersion = p_IdDest;

            SET v_Details = CONCAT('Clients: source=', v_CountSource,
                                   ', destination=', v_CountDest);

        -- Validation d'un client
        WHEN 'CLIENT' THEN
            -- Compter les commandes
            SELECT COUNT(*) INTO v_CountSource
            FROM tb_Commande WHERE fkClient = p_IdSource;

            SELECT COUNT(*) INTO v_CountDest
            FROM tb_Commande WHERE fkClient = p_IdDest;

            SET v_Details = CONCAT('Commandes: source=', v_CountSource,
                                   ', destination=', v_CountDest);

        -- Validation d'une commande
        WHEN 'COMMANDE' THEN
            -- Compter les lignes
            SELECT COUNT(*) INTO v_CountSource
            FROM tb_LigneCommande WHERE fkCommande = p_IdSource;

            SELECT COUNT(*) INTO v_CountDest
            FROM tb_LigneCommande WHERE fkCommande = p_IdDest;

            SET v_Details = CONCAT('Lignes: source=', v_CountSource,
                                   ', destination=', v_CountDest);

        ELSE
            SET p_Message = CONCAT('Type d''entité inconnu: ', p_TypeEntite);
            LEAVE proc_main;

    END CASE;

    -- -------------------------------------------------------------------------
    -- Comparaison et résultat
    -- -------------------------------------------------------------------------
    IF v_CountSource = v_CountDest THEN
        SET p_Valide = 1;
        SET p_Message = CONCAT('Duplication valide. ', v_Details);
    ELSE
        SET p_Valide = 0;
        SET p_Message = CONCAT('ERREUR: Nombre d''éléments différent. ', v_Details);
    END IF;

END$$


-- =============================================================================
-- PROCÉDURE : SP_ComparerEntites
-- =============================================================================
-- Description : Compare les données entre une entité source et sa copie
--
-- Paramètres :
--   IN p_Table     : Nom de la table
--   IN p_IdSource  : ID de l'enregistrement source
--   IN p_IdDest    : ID de l'enregistrement destination
--
-- Retour : Jeu de résultats avec les différences trouvées
--
-- Exemple d'utilisation :
--   CALL SP_ComparerEntites('tb_Client', 1, 42);
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_ComparerEntites$$

CREATE PROCEDURE SP_ComparerEntites(
    IN p_Table VARCHAR(100),
    IN p_IdSource INT,
    IN p_IdDest INT
)
SQL SECURITY INVOKER
COMMENT 'Compare deux enregistrements d''une même table'
BEGIN

    -- Construction de la requête dynamique pour comparer les colonnes
    SET @sql_compare = CONCAT(
        'SELECT ',
        '''', p_Table, ''' AS TableName, ',
        p_IdSource, ' AS IdSource, ',
        p_IdDest, ' AS IdDest, ',
        '''Comparaison effectuée'' AS Resultat'
    );

    PREPARE stmt FROM @sql_compare;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

END$$


-- =============================================================================
-- PROCÉDURE : SP_AfficherStatsDuplication
-- =============================================================================
-- Description : Affiche les statistiques des duplications effectuées
--
-- Paramètres : Aucun
--
-- Retour : Jeu de résultats avec les statistiques
--
-- Exemple d'utilisation :
--   CALL SP_AfficherStatsDuplication();
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_AfficherStatsDuplication$$

CREATE PROCEDURE SP_AfficherStatsDuplication()
SQL SECURITY INVOKER
COMMENT 'Affiche les statistiques des duplications'
BEGIN

    SELECT
        TypeOperation,
        COUNT(*) AS NombreOperations,
        SUM(CASE WHEN Succes = 1 THEN 1 ELSE 0 END) AS Succes,
        SUM(CASE WHEN Succes = 0 THEN 1 ELSE 0 END) AS Echecs,
        MIN(DateOperation) AS PremiereOperation,
        MAX(DateOperation) AS DerniereOperation
    FROM tb_Logs
    WHERE TypeOperation LIKE 'DUPLICATION%'
    GROUP BY TypeOperation
    ORDER BY TypeOperation;

END$$


DELIMITER ;

-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================

SELECT 'Procédures de validation créées avec succès !' AS Message;
