-- =============================================================================
-- Procédures de Duplication - MariaDB 11.8
-- =============================================================================
--
-- Ce fichier contient les procédures stockées de duplication de données.
-- Elles permettent de copier des enregistrements avec toutes leurs dépendances
-- en maintenant l'intégrité référentielle.
--
-- Hiérarchie de duplication :
--   SP_DupliquerProjet (niveau le plus haut)
--     └── SP_DupliquerVersion
--           └── SP_DupliquerClient
--                 └── SP_DupliquerCommande
--                       └── SP_DupliquerLignesCommande
--
-- Auteur : Nicolas DEOUX (NDXDev@gmail.com)
-- Date   : Décembre 2025
-- =============================================================================

USE duplication_db;

DELIMITER $$

-- =============================================================================
-- PROCÉDURE : SP_DupliquerLignesCommande
-- =============================================================================
-- Description : Duplique toutes les lignes d'une commande vers une nouvelle
--               commande.
--
-- Paramètres :
--   IN  p_CommandeSource : ID de la commande source
--   IN  p_CommandeDest   : ID de la commande destination
--   OUT p_Erreur         : 0 = succès, 1 = erreur
--
-- Détails techniques :
--   - Utilise un curseur pour parcourir les lignes
--   - Renumérote les lignes automatiquement
--   - Recalcule les montants HT
--
-- Exemple d'utilisation :
--   CALL SP_DupliquerLignesCommande(1, 42, @erreur);
--   SELECT IF(@erreur = 0, 'Succès', 'Erreur');
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_DupliquerLignesCommande$$

CREATE PROCEDURE SP_DupliquerLignesCommande(
    IN p_CommandeSource INT,
    IN p_CommandeDest INT,
    OUT p_Erreur INT
)
SQL SECURITY INVOKER
COMMENT 'Duplique les lignes d''une commande vers une nouvelle commande'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_Done INT DEFAULT FALSE;
    DECLARE v_NumLigne INT DEFAULT 0;

    -- Variables pour les données de la ligne source
    DECLARE v_Reference VARCHAR(50);
    DECLARE v_Designation VARCHAR(500);
    DECLARE v_Quantite DECIMAL(15,3);
    DECLARE v_Unite VARCHAR(20);
    DECLARE v_PrixUnitaire DECIMAL(15,4);
    DECLARE v_Remise DECIMAL(5,2);
    DECLARE v_MontantHT DECIMAL(15,2);

    DECLARE v_NouvelId INT DEFAULT 0;

    -- -------------------------------------------------------------------------
    -- Curseur pour parcourir les lignes de commande source
    -- -------------------------------------------------------------------------
    DECLARE cur_Lignes CURSOR FOR
        SELECT
            Reference,
            Designation,
            Quantite,
            Unite,
            PrixUnitaire,
            Remise,
            MontantHT
        FROM tb_LigneCommande
        WHERE fkCommande = p_CommandeSource
        ORDER BY NumLigne ASC;

    -- Handler pour la fin du curseur
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Done = TRUE;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs
    -- -------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_Erreur = 1;
        RESIGNAL;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_Erreur = 0;

    -- Validation des paramètres
    IF p_CommandeSource IS NULL OR p_CommandeSource < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    IF p_CommandeDest IS NULL OR p_CommandeDest < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Parcours et duplication des lignes
    -- -------------------------------------------------------------------------
    OPEN cur_Lignes;

    boucle_lignes: LOOP
        -- Réinitialisation des variables
        SET v_Reference = NULL;
        SET v_Designation = NULL;
        SET v_Quantite = NULL;
        SET v_Unite = NULL;
        SET v_PrixUnitaire = NULL;
        SET v_Remise = NULL;
        SET v_MontantHT = NULL;

        -- Lecture de la ligne suivante
        FETCH cur_Lignes INTO
            v_Reference,
            v_Designation,
            v_Quantite,
            v_Unite,
            v_PrixUnitaire,
            v_Remise,
            v_MontantHT;

        -- Sortir si plus de lignes
        IF v_Done THEN
            LEAVE boucle_lignes;
        END IF;

        -- Incrémenter le numéro de ligne
        SET v_NumLigne = v_NumLigne + 1;

        -- Insertion de la nouvelle ligne
        INSERT INTO tb_LigneCommande (
            fkCommande,
            NumLigne,
            Reference,
            Designation,
            Quantite,
            Unite,
            PrixUnitaire,
            Remise,
            MontantHT,
            DateCrea,
            ParQui
        ) VALUES (
            p_CommandeDest,
            v_NumLigne,
            v_Reference,
            v_Designation,
            v_Quantite,
            v_Unite,
            v_PrixUnitaire,
            v_Remise,
            v_MontantHT,
            NOW(),
            'SP_DupliquerLignesCommande'
        );

        SET v_NouvelId = LAST_INSERT_ID();

        -- Vérification de l'insertion
        IF v_NouvelId < 1 THEN
            SET p_Erreur = 1;
            LEAVE boucle_lignes;
        END IF;

    END LOOP boucle_lignes;

    CLOSE cur_Lignes;

END$$


-- =============================================================================
-- PROCÉDURE : SP_DupliquerCommande
-- =============================================================================
-- Description : Duplique une commande avec toutes ses lignes
--
-- Paramètres :
--   IN  p_CommandeSource : ID de la commande source
--   IN  p_ClientDest     : ID du client destination
--   OUT p_CommandeDest   : ID de la nouvelle commande créée
--   OUT p_Erreur         : 0 = succès, 1 = erreur
--
-- Détails techniques :
--   - Génère un nouveau numéro de commande
--   - Duplique les métadonnées de la commande
--   - Appelle SP_DupliquerLignesCommande pour les lignes
--
-- Exemple d'utilisation :
--   CALL SP_DupliquerCommande(1, 42, @nouvel_id, @erreur);
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_DupliquerCommande$$

CREATE PROCEDURE SP_DupliquerCommande(
    IN p_CommandeSource INT,
    IN p_ClientDest INT,
    OUT p_CommandeDest INT,
    OUT p_Erreur INT
)
SQL SECURITY INVOKER
COMMENT 'Duplique une commande avec toutes ses lignes'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_NumCommande VARCHAR(50);
    DECLARE v_DateCommande DATE;
    DECLARE v_DateLivraison DATE;
    DECLARE v_TauxTVA DECIMAL(5,2);
    DECLARE v_Remise DECIMAL(5,2);
    DECLARE v_Notes TEXT;
    DECLARE v_NouveauNum INT;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs
    -- -------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_Erreur = 1;
        SET p_CommandeDest = -1;
        RESIGNAL;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_Erreur = 0;
    SET p_CommandeDest = -1;

    -- Validation des paramètres
    IF p_CommandeSource IS NULL OR p_CommandeSource < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    IF p_ClientDest IS NULL OR p_ClientDest < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Récupération des données de la commande source
    -- -------------------------------------------------------------------------
    SELECT
        NumCommande,
        DateCommande,
        DateLivraison,
        TauxTVA,
        Remise,
        Notes
    INTO
        v_NumCommande,
        v_DateCommande,
        v_DateLivraison,
        v_TauxTVA,
        v_Remise,
        v_Notes
    FROM tb_Commande
    WHERE id = p_CommandeSource
    LIMIT 1;

    -- Vérifier que la commande source existe
    IF v_NumCommande IS NULL THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Génération d'un nouveau numéro de commande
    -- -------------------------------------------------------------------------
    CALL SP_GenererNumero('COMMANDE', 1, v_NouveauNum);

    SET v_NumCommande = CONCAT('CMD-', LPAD(v_NouveauNum, 6, '0'));

    -- -------------------------------------------------------------------------
    -- Création de la nouvelle commande
    -- -------------------------------------------------------------------------
    INSERT INTO tb_Commande (
        fkClient,
        NumCommande,
        DateCommande,
        DateLivraison,
        Statut,
        MontantHT,
        TauxTVA,
        MontantTTC,
        Remise,
        Notes,
        DateCrea,
        ParQui
    ) VALUES (
        p_ClientDest,
        v_NumCommande,
        CURDATE(),             -- Nouvelle date de commande
        v_DateLivraison,
        'EN_ATTENTE',          -- Statut initial
        0.00,                  -- Sera recalculé
        v_TauxTVA,
        0.00,                  -- Sera recalculé
        v_Remise,
        CONCAT('[Copie de ', p_CommandeSource, '] ', COALESCE(v_Notes, '')),
        NOW(),
        'SP_DupliquerCommande'
    );

    SET p_CommandeDest = LAST_INSERT_ID();

    -- Vérification de l'insertion
    IF p_CommandeDest < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Duplication des lignes de commande
    -- -------------------------------------------------------------------------
    CALL SP_DupliquerLignesCommande(p_CommandeSource, p_CommandeDest, @err_lignes);

    IF @err_lignes = 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Recalcul des montants de la commande
    -- -------------------------------------------------------------------------
    UPDATE tb_Commande c
    SET
        MontantHT = (
            SELECT COALESCE(SUM(MontantHT), 0)
            FROM tb_LigneCommande
            WHERE fkCommande = c.id
        ),
        MontantTTC = MontantHT * (1 + TauxTVA / 100),
        DateModif = NOW()
    WHERE c.id = p_CommandeDest;

    -- -------------------------------------------------------------------------
    -- Journalisation
    -- -------------------------------------------------------------------------
    CALL SP_LogOperation(
        'DUPLICATION_COMMANDE',
        'tb_Commande',
        p_CommandeSource,
        p_CommandeDest,
        CONCAT('Commande dupliquée : ', v_NumCommande),
        1,
        'SP_DupliquerCommande'
    );

END$$


-- =============================================================================
-- PROCÉDURE : SP_DupliquerClient
-- =============================================================================
-- Description : Duplique un client avec toutes ses commandes
--
-- Paramètres :
--   IN  p_ClientSource : ID du client source
--   IN  p_VersionDest  : ID de la version destination
--   IN  p_NouveauCode  : Nouveau code client (optionnel, auto-généré si NULL)
--   OUT p_ClientDest   : ID du nouveau client créé
--   OUT p_Erreur       : 0 = succès, 1 = erreur
--
-- Détails techniques :
--   - Utilise une table temporaire EqCommande pour le mapping des commandes
--   - Duplique toutes les commandes du client
--   - Chaque commande est dupliquée avec ses lignes
--
-- Exemple d'utilisation :
--   CALL SP_DupliquerClient(1, 5, 'CLI-NEW', @nouvel_id, @erreur);
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_DupliquerClient$$

CREATE PROCEDURE SP_DupliquerClient(
    IN p_ClientSource INT,
    IN p_VersionDest INT,
    IN p_NouveauCode VARCHAR(20),
    OUT p_ClientDest INT,
    OUT p_Erreur INT
)
SQL SECURITY INVOKER
COMMENT 'Duplique un client avec toutes ses commandes'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_Done INT DEFAULT FALSE;
    DECLARE v_Code VARCHAR(20);
    DECLARE v_RaisonSociale VARCHAR(200);
    DECLARE v_Adresse VARCHAR(500);
    DECLARE v_CodePostal VARCHAR(10);
    DECLARE v_Ville VARCHAR(100);
    DECLARE v_Pays VARCHAR(100);
    DECLARE v_Telephone VARCHAR(20);
    DECLARE v_Email VARCHAR(200);
    DECLARE v_Contact VARCHAR(200);
    DECLARE v_NouveauNum INT;

    -- Variables pour la duplication des commandes
    DECLARE v_CommandeSourceId INT;
    DECLARE v_CommandeDestId INT;
    DECLARE v_ErreurCommande INT;

    -- -------------------------------------------------------------------------
    -- Curseur pour les commandes du client
    -- -------------------------------------------------------------------------
    DECLARE cur_Commandes CURSOR FOR
        SELECT id
        FROM tb_Commande
        WHERE fkClient = p_ClientSource
        ORDER BY id ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Done = TRUE;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs
    -- -------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_Erreur = 1;
        SET p_ClientDest = -1;
        -- Nettoyage de la table temporaire
        DROP TEMPORARY TABLE IF EXISTS EqCommande;
        RESIGNAL;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_Erreur = 0;
    SET p_ClientDest = -1;

    -- Validation des paramètres
    IF p_ClientSource IS NULL OR p_ClientSource < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    IF p_VersionDest IS NULL OR p_VersionDest < 1 THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Récupération des données du client source
    -- -------------------------------------------------------------------------
    SELECT
        Code,
        RaisonSociale,
        Adresse,
        CodePostal,
        Ville,
        Pays,
        Telephone,
        Email,
        Contact
    INTO
        v_Code,
        v_RaisonSociale,
        v_Adresse,
        v_CodePostal,
        v_Ville,
        v_Pays,
        v_Telephone,
        v_Email,
        v_Contact
    FROM tb_Client
    WHERE id = p_ClientSource
    LIMIT 1;

    -- Vérifier que le client source existe
    IF v_Code IS NULL THEN
        SET p_Erreur = 1;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Génération du code client si non fourni
    -- -------------------------------------------------------------------------
    IF p_NouveauCode IS NULL OR TRIM(p_NouveauCode) = '' THEN
        CALL SP_GenererNumero('CLIENT', 1, v_NouveauNum);
        SET v_Code = CONCAT('CLI-', LPAD(v_NouveauNum, 5, '0'));
    ELSE
        SET v_Code = p_NouveauCode;
    END IF;

    -- -------------------------------------------------------------------------
    -- Création de la table temporaire de mapping des commandes
    -- -------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS EqCommande;
    CREATE TEMPORARY TABLE EqCommande (
        id INT NOT NULL AUTO_INCREMENT,
        idPrev INT DEFAULT NULL,
        idNext INT DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_prev (idPrev)
    ) ENGINE=MEMORY;

    -- -------------------------------------------------------------------------
    -- Création du nouveau client
    -- -------------------------------------------------------------------------
    INSERT INTO tb_Client (
        fkVersion,
        Code,
        RaisonSociale,
        Adresse,
        CodePostal,
        Ville,
        Pays,
        Telephone,
        Email,
        Contact,
        Actif,
        DateCrea,
        ParQui
    ) VALUES (
        p_VersionDest,
        v_Code,
        CONCAT('[Copie] ', v_RaisonSociale),
        v_Adresse,
        v_CodePostal,
        v_Ville,
        v_Pays,
        v_Telephone,
        v_Email,
        v_Contact,
        1,
        NOW(),
        'SP_DupliquerClient'
    );

    SET p_ClientDest = LAST_INSERT_ID();

    -- Vérification de l'insertion
    IF p_ClientDest < 1 THEN
        SET p_Erreur = 1;
        DROP TEMPORARY TABLE IF EXISTS EqCommande;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Duplication des commandes du client
    -- -------------------------------------------------------------------------
    OPEN cur_Commandes;

    boucle_commandes: LOOP
        SET v_CommandeSourceId = -1;
        SET v_CommandeDestId = -1;

        FETCH cur_Commandes INTO v_CommandeSourceId;

        IF v_Done THEN
            LEAVE boucle_commandes;
        END IF;

        IF v_CommandeSourceId > 0 THEN
            -- Dupliquer la commande
            CALL SP_DupliquerCommande(
                v_CommandeSourceId,
                p_ClientDest,
                v_CommandeDestId,
                v_ErreurCommande
            );

            IF v_ErreurCommande = 1 THEN
                SET p_Erreur = 1;
                LEAVE boucle_commandes;
            END IF;

            -- Enregistrer le mapping
            INSERT INTO EqCommande (idPrev, idNext)
            VALUES (v_CommandeSourceId, v_CommandeDestId);
        END IF;

    END LOOP boucle_commandes;

    CLOSE cur_Commandes;

    -- -------------------------------------------------------------------------
    -- Nettoyage
    -- -------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS EqCommande;

    -- -------------------------------------------------------------------------
    -- Journalisation
    -- -------------------------------------------------------------------------
    IF p_Erreur = 0 THEN
        CALL SP_LogOperation(
            'DUPLICATION_CLIENT',
            'tb_Client',
            p_ClientSource,
            p_ClientDest,
            CONCAT('Client dupliqué : ', v_Code),
            1,
            'SP_DupliquerClient'
        );
    END IF;

END$$


-- =============================================================================
-- PROCÉDURE : SP_DupliquerVersion
-- =============================================================================
-- Description : Duplique une version complète avec tous ses clients et commandes
--
-- Paramètres :
--   IN  p_VersionSource  : ID de la version source
--   IN  p_ProjetDest     : ID du projet destination
--   IN  p_NouveauLibelle : Libellé de la nouvelle version (optionnel)
--   IN  p_IdUtilisateur  : ID de l'utilisateur effectuant la duplication
--   OUT p_VersionDest    : ID de la nouvelle version créée
--   OUT p_Succes         : 1 = succès, 0 = échec
--
-- Détails techniques :
--   - Utilise une table temporaire EqClient pour le mapping des clients
--   - Transaction globale pour garantir l'atomicité
--   - Gestion des erreurs avec rollback automatique
--
-- Exemple d'utilisation :
--   CALL SP_DupliquerVersion(1, 1, 'Version 2.0', 1, @nouvel_id, @succes);
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_DupliquerVersion$$

CREATE PROCEDURE SP_DupliquerVersion(
    IN p_VersionSource INT,
    IN p_ProjetDest INT,
    IN p_NouveauLibelle VARCHAR(200),
    IN p_IdUtilisateur INT,
    OUT p_VersionDest INT,
    OUT p_Succes INT
)
SQL SECURITY INVOKER
COMMENT 'Duplique une version avec tous ses clients et commandes'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_Done INT DEFAULT FALSE;
    DECLARE v_NumVersion INT;
    DECLARE v_Libelle VARCHAR(200);
    DECLARE v_Description TEXT;
    DECLARE v_NouveauNumVersion INT;
    DECLARE v_Erreur INT DEFAULT 0;

    -- Variables pour la duplication des clients
    DECLARE v_ClientSourceId INT;
    DECLARE v_ClientDestId INT;
    DECLARE v_ErreurClient INT;

    -- -------------------------------------------------------------------------
    -- Curseur pour les clients de la version
    -- -------------------------------------------------------------------------
    DECLARE cur_Clients CURSOR FOR
        SELECT id
        FROM tb_Client
        WHERE fkVersion = p_VersionSource
        ORDER BY id ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Done = TRUE;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs avec rollback
    -- -------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_Succes = 0;
        SET p_VersionDest = -1;
        DROP TEMPORARY TABLE IF EXISTS EqClient;
        DROP TEMPORARY TABLE IF EXISTS EqCommande;
        RESIGNAL;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_Succes = 0;
    SET p_VersionDest = -1;

    -- Validation des paramètres
    IF p_VersionSource IS NULL OR p_VersionSource < 1 THEN
        LEAVE proc_main;
    END IF;

    IF p_ProjetDest IS NULL OR p_ProjetDest < 1 THEN
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Début de la transaction
    -- -------------------------------------------------------------------------
    START TRANSACTION;

    -- -------------------------------------------------------------------------
    -- Récupération des données de la version source
    -- -------------------------------------------------------------------------
    SELECT
        NumVersion,
        Libelle,
        Description
    INTO
        v_NumVersion,
        v_Libelle,
        v_Description
    FROM tb_Version
    WHERE id = p_VersionSource
    LIMIT 1;

    -- Vérifier que la version source existe
    IF v_NumVersion IS NULL THEN
        ROLLBACK;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Génération du nouveau numéro de version
    -- -------------------------------------------------------------------------
    -- Trouver le prochain numéro de version pour ce projet
    SELECT COALESCE(MAX(NumVersion), 0) + 1
    INTO v_NouveauNumVersion
    FROM tb_Version
    WHERE fkProjet = p_ProjetDest;

    -- Définir le libellé
    IF p_NouveauLibelle IS NULL OR TRIM(p_NouveauLibelle) = '' THEN
        SET v_Libelle = CONCAT('Version ', v_NouveauNumVersion);
    ELSE
        SET v_Libelle = p_NouveauLibelle;
    END IF;

    -- -------------------------------------------------------------------------
    -- Création des tables temporaires de mapping
    -- -------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS EqClient;
    CREATE TEMPORARY TABLE EqClient (
        id INT NOT NULL AUTO_INCREMENT,
        idPrev INT DEFAULT NULL,
        idNext INT DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_prev (idPrev)
    ) ENGINE=MEMORY;

    -- -------------------------------------------------------------------------
    -- Création de la nouvelle version
    -- -------------------------------------------------------------------------
    INSERT INTO tb_Version (
        fkProjet,
        NumVersion,
        Libelle,
        Description,
        Statut,
        fkUtilisateur,
        DateCrea,
        ParQui
    ) VALUES (
        p_ProjetDest,
        v_NouveauNumVersion,
        v_Libelle,
        CONCAT('[Copie de V', v_NumVersion, '] ', COALESCE(v_Description, '')),
        'BROUILLON',
        p_IdUtilisateur,
        NOW(),
        'SP_DupliquerVersion'
    );

    SET p_VersionDest = LAST_INSERT_ID();

    -- Vérification de l'insertion
    IF p_VersionDest < 1 THEN
        SET v_Erreur = 1;
    END IF;

    -- -------------------------------------------------------------------------
    -- Duplication des clients de la version
    -- -------------------------------------------------------------------------
    IF v_Erreur = 0 THEN
        OPEN cur_Clients;

        boucle_clients: LOOP
            SET v_ClientSourceId = -1;
            SET v_ClientDestId = -1;

            FETCH cur_Clients INTO v_ClientSourceId;

            IF v_Done THEN
                LEAVE boucle_clients;
            END IF;

            IF v_ClientSourceId > 0 THEN
                -- Dupliquer le client
                CALL SP_DupliquerClient(
                    v_ClientSourceId,
                    p_VersionDest,
                    NULL,  -- Code auto-généré
                    v_ClientDestId,
                    v_ErreurClient
                );

                IF v_ErreurClient = 1 THEN
                    SET v_Erreur = 1;
                    LEAVE boucle_clients;
                END IF;

                -- Enregistrer le mapping
                INSERT INTO EqClient (idPrev, idNext)
                VALUES (v_ClientSourceId, v_ClientDestId);
            END IF;

        END LOOP boucle_clients;

        CLOSE cur_Clients;
    END IF;

    -- -------------------------------------------------------------------------
    -- Finalisation
    -- -------------------------------------------------------------------------
    IF v_Erreur = 0 THEN
        COMMIT;
        SET p_Succes = 1;

        -- Journalisation
        CALL SP_LogOperation(
            'DUPLICATION_VERSION',
            'tb_Version',
            p_VersionSource,
            p_VersionDest,
            CONCAT('Version dupliquée : ', v_Libelle),
            1,
            'SP_DupliquerVersion'
        );
    ELSE
        ROLLBACK;
        SET p_Succes = 0;
        SET p_VersionDest = -1;
    END IF;

    -- Nettoyage
    DROP TEMPORARY TABLE IF EXISTS EqClient;

END$$


-- =============================================================================
-- PROCÉDURE : SP_DupliquerProjet
-- =============================================================================
-- Description : Duplique un projet complet avec toutes ses versions, clients
--               et commandes
--
-- Paramètres :
--   IN  p_ProjetSource   : ID du projet source
--   IN  p_NouveauLibelle : Libellé du nouveau projet
--   IN  p_IdUtilisateur  : ID de l'utilisateur effectuant la duplication
--   OUT p_Succes         : 1 = succès, 0 = échec
--   OUT p_ProjetDest     : ID du nouveau projet créé
--
-- Détails techniques :
--   - Transaction globale englobant toute la duplication
--   - Tables temporaires pour le mapping des IDs
--   - Gestion d'erreur complète avec rollback
--   - Journalisation des opérations
--
-- Exemple d'utilisation :
--   CALL SP_DupliquerProjet(1, 'Nouveau Projet 2025', 1, @succes, @nouvel_id);
--   SELECT @succes, @nouvel_id;
-- =============================================================================
DROP PROCEDURE IF EXISTS SP_DupliquerProjet$$

CREATE PROCEDURE SP_DupliquerProjet(
    IN p_ProjetSource INT,
    IN p_NouveauLibelle VARCHAR(200),
    IN p_IdUtilisateur INT,
    OUT p_Succes INT,
    OUT p_ProjetDest INT
)
SQL SECURITY INVOKER
COMMENT 'Duplique un projet complet avec toutes ses dépendances'
proc_main:BEGIN

    -- -------------------------------------------------------------------------
    -- Déclaration des variables
    -- -------------------------------------------------------------------------
    DECLARE v_Done INT DEFAULT FALSE;
    DECLARE v_NumProjet INT;
    DECLARE v_Libelle VARCHAR(200);
    DECLARE v_Description TEXT;
    DECLARE v_DateDebut DATE;
    DECLARE v_DateFin DATE;
    DECLARE v_Budget DECIMAL(15,2);
    DECLARE v_NouveauNumProjet INT;
    DECLARE v_Erreur INT DEFAULT 0;

    -- Variables pour la duplication des versions
    DECLARE v_VersionSourceId INT;
    DECLARE v_VersionDestId INT;
    DECLARE v_SuccesVersion INT;

    -- -------------------------------------------------------------------------
    -- Curseur pour les versions du projet
    -- -------------------------------------------------------------------------
    DECLARE cur_Versions CURSOR FOR
        SELECT id
        FROM tb_Version
        WHERE fkProjet = p_ProjetSource
        ORDER BY NumVersion ASC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_Done = TRUE;

    -- -------------------------------------------------------------------------
    -- Gestionnaire d'erreurs avec rollback
    -- -------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_Succes = 0;
        SET p_ProjetDest = -1;
        DROP TEMPORARY TABLE IF EXISTS EqVersion;
        DROP TEMPORARY TABLE IF EXISTS EqClient;
        DROP TEMPORARY TABLE IF EXISTS EqCommande;

        -- Log de l'erreur
        CALL SP_LogOperation(
            'DUPLICATION_PROJET',
            'tb_Projet',
            p_ProjetSource,
            -1,
            'Erreur lors de la duplication du projet',
            0,
            'SP_DupliquerProjet'
        );

        RESIGNAL;
    END;

    -- -------------------------------------------------------------------------
    -- Initialisation
    -- -------------------------------------------------------------------------
    SET p_Succes = 0;
    SET p_ProjetDest = -1;

    -- Validation des paramètres
    IF p_ProjetSource IS NULL OR p_ProjetSource < 1 THEN
        LEAVE proc_main;
    END IF;

    IF p_NouveauLibelle IS NULL OR TRIM(p_NouveauLibelle) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Le libellé du projet ne peut pas être vide';
    END IF;

    -- -------------------------------------------------------------------------
    -- Augmentation du timeout pour les transactions longues
    -- -------------------------------------------------------------------------
    SET @old_lock_wait_timeout = @@session.innodb_lock_wait_timeout;
    IF @old_lock_wait_timeout < 120 THEN
        SET @@session.innodb_lock_wait_timeout = 120;
    END IF;

    -- -------------------------------------------------------------------------
    -- Début de la transaction principale
    -- -------------------------------------------------------------------------
    START TRANSACTION;

    -- -------------------------------------------------------------------------
    -- Récupération des données du projet source
    -- -------------------------------------------------------------------------
    SELECT
        NumProjet,
        Libelle,
        Description,
        DateDebut,
        DateFin,
        Budget
    INTO
        v_NumProjet,
        v_Libelle,
        v_Description,
        v_DateDebut,
        v_DateFin,
        v_Budget
    FROM tb_Projet
    WHERE id = p_ProjetSource
    LIMIT 1;

    -- Vérifier que le projet source existe
    IF v_NumProjet IS NULL THEN
        ROLLBACK;
        LEAVE proc_main;
    END IF;

    -- -------------------------------------------------------------------------
    -- Génération du nouveau numéro de projet
    -- -------------------------------------------------------------------------
    CALL SP_GenererNumero('PROJET', 1, v_NouveauNumProjet);

    -- -------------------------------------------------------------------------
    -- Création de la table temporaire de mapping des versions
    -- -------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS EqVersion;
    CREATE TEMPORARY TABLE EqVersion (
        id INT NOT NULL AUTO_INCREMENT,
        idPrev INT DEFAULT NULL,
        idNext INT DEFAULT NULL,
        PRIMARY KEY (id),
        KEY idx_prev (idPrev)
    ) ENGINE=MEMORY;

    -- -------------------------------------------------------------------------
    -- Création du nouveau projet
    -- -------------------------------------------------------------------------
    INSERT INTO tb_Projet (
        NumProjet,
        Libelle,
        Description,
        fkCreateur,
        Statut,
        DateDebut,
        DateFin,
        Budget,
        DateCrea,
        ParQui
    ) VALUES (
        v_NouveauNumProjet,
        p_NouveauLibelle,
        CONCAT('[Copie du projet ', v_NumProjet, '] ', COALESCE(v_Description, '')),
        p_IdUtilisateur,
        'ACTIF',
        v_DateDebut,
        v_DateFin,
        v_Budget,
        NOW(),
        'SP_DupliquerProjet'
    );

    SET p_ProjetDest = LAST_INSERT_ID();

    -- Vérification de l'insertion
    IF p_ProjetDest < 1 THEN
        SET v_Erreur = 1;
    END IF;

    -- -------------------------------------------------------------------------
    -- Duplication des versions du projet
    -- -------------------------------------------------------------------------
    IF v_Erreur = 0 THEN
        OPEN cur_Versions;

        boucle_versions: LOOP
            SET v_VersionSourceId = -1;
            SET v_VersionDestId = -1;

            FETCH cur_Versions INTO v_VersionSourceId;

            IF v_Done THEN
                LEAVE boucle_versions;
            END IF;

            IF v_VersionSourceId > 0 THEN
                -- Dupliquer la version
                CALL SP_DupliquerVersion(
                    v_VersionSourceId,
                    p_ProjetDest,
                    NULL,  -- Libellé auto-généré
                    p_IdUtilisateur,
                    v_VersionDestId,
                    v_SuccesVersion
                );

                IF v_SuccesVersion = 0 THEN
                    SET v_Erreur = 1;
                    LEAVE boucle_versions;
                END IF;

                -- Enregistrer le mapping
                INSERT INTO EqVersion (idPrev, idNext)
                VALUES (v_VersionSourceId, v_VersionDestId);
            END IF;

        END LOOP boucle_versions;

        CLOSE cur_Versions;
    END IF;

    -- -------------------------------------------------------------------------
    -- Finalisation
    -- -------------------------------------------------------------------------
    IF v_Erreur = 0 THEN
        COMMIT;
        SET p_Succes = 1;

        -- Journalisation du succès
        CALL SP_LogOperation(
            'DUPLICATION_PROJET',
            'tb_Projet',
            p_ProjetSource,
            p_ProjetDest,
            CONCAT('Projet dupliqué avec succès : ', p_NouveauLibelle,
                   ' (Numéro: ', v_NouveauNumProjet, ')'),
            1,
            'SP_DupliquerProjet'
        );
    ELSE
        ROLLBACK;
        SET p_Succes = 0;
        SET p_ProjetDest = -1;

        -- Journalisation de l'échec
        CALL SP_LogOperation(
            'DUPLICATION_PROJET',
            'tb_Projet',
            p_ProjetSource,
            -1,
            'Échec de la duplication du projet',
            0,
            'SP_DupliquerProjet'
        );
    END IF;

    -- -------------------------------------------------------------------------
    -- Nettoyage
    -- -------------------------------------------------------------------------
    DROP TEMPORARY TABLE IF EXISTS EqVersion;

    -- Restauration du timeout
    SET @@session.innodb_lock_wait_timeout = @old_lock_wait_timeout;

END$$


DELIMITER ;

-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================

SELECT 'Procédures de duplication créées avec succès !' AS Message;
