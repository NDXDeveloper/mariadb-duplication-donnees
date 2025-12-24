-- =============================================================================
-- Schéma de Base de Données - Duplication de Données MariaDB 11.8
-- =============================================================================
--
-- Ce fichier crée la structure de base de données utilisée pour démontrer
-- les techniques de duplication de données via des procédures stockées.
--
-- Structure hiérarchique :
--   Projet -> Version -> Client -> Commande -> LigneCommande
--
-- Auteur : Nicolas DEOUX (NDXDev@gmail.com)
-- Date   : Décembre 2025
-- =============================================================================

-- Utiliser la base de données
USE duplication_db;

-- =============================================================================
-- SECTION 1 : Suppression des tables existantes (ordre inverse des dépendances)
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS tb_LigneCommande;
DROP TABLE IF EXISTS tb_Commande;
DROP TABLE IF EXISTS tb_Client;
DROP TABLE IF EXISTS tb_Version;
DROP TABLE IF EXISTS tb_Projet;
DROP TABLE IF EXISTS tb_Compteur;
DROP TABLE IF EXISTS tb_Utilisateur;
DROP TABLE IF EXISTS tb_Logs;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- SECTION 2 : Tables de référence et configuration
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table : tb_Utilisateur
-- Description : Utilisateurs du système
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Utilisateur (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    Login VARCHAR(100) NOT NULL COMMENT 'Login utilisateur',
    Nom VARCHAR(200) NOT NULL COMMENT 'Nom complet',
    Email VARCHAR(200) DEFAULT NULL COMMENT 'Adresse email',
    Actif TINYINT(4) NOT NULL DEFAULT 1 COMMENT '1=actif, 0=inactif',
    DateCrea DATETIME DEFAULT NULL COMMENT 'Date de création',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Créé/modifié par',
    PRIMARY KEY (id),
    UNIQUE KEY uk_login (Login)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Table des utilisateurs du système';

-- -----------------------------------------------------------------------------
-- Table : tb_Compteur
-- Description : Compteurs pour la génération de numéros séquentiels
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Compteur (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    TypeCompteur VARCHAR(50) NOT NULL COMMENT 'Type de compteur (PROJET, VERSION, etc.)',
    Prefixe VARCHAR(10) DEFAULT NULL COMMENT 'Préfixe optionnel',
    ValeurActuelle INT(11) NOT NULL DEFAULT 0 COMMENT 'Valeur actuelle du compteur',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    PRIMARY KEY (id),
    UNIQUE KEY uk_type (TypeCompteur)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Compteurs pour génération de numéros';

-- -----------------------------------------------------------------------------
-- Table : tb_Logs
-- Description : Journal des opérations de duplication
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Logs (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    TypeOperation VARCHAR(50) NOT NULL COMMENT 'Type d''opération',
    TableSource VARCHAR(100) DEFAULT NULL COMMENT 'Table source',
    IdSource INT(11) DEFAULT NULL COMMENT 'ID source',
    IdDestination INT(11) DEFAULT NULL COMMENT 'ID destination',
    Message TEXT DEFAULT NULL COMMENT 'Message détaillé',
    Succes TINYINT(4) NOT NULL DEFAULT 1 COMMENT '1=succès, 0=échec',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Utilisateur',
    DateOperation DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Date de l''opération',
    PRIMARY KEY (id),
    KEY idx_type_date (TypeOperation, DateOperation)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Journal des opérations de duplication';

-- =============================================================================
-- SECTION 3 : Tables métier principales
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table : tb_Projet
-- Description : Projets (niveau le plus haut de la hiérarchie)
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Projet (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    NumProjet INT(11) NOT NULL COMMENT 'Numéro de projet séquentiel',
    Libelle VARCHAR(200) NOT NULL COMMENT 'Libellé du projet',
    Description TEXT DEFAULT NULL COMMENT 'Description détaillée',
    fkCreateur INT(11) DEFAULT NULL COMMENT 'FK vers l''utilisateur créateur',
    Statut ENUM('ACTIF', 'ARCHIVE', 'ANNULE') NOT NULL DEFAULT 'ACTIF' COMMENT 'Statut du projet',
    DateDebut DATE DEFAULT NULL COMMENT 'Date de début prévue',
    DateFin DATE DEFAULT NULL COMMENT 'Date de fin prévue',
    Budget DECIMAL(15,2) DEFAULT NULL COMMENT 'Budget alloué',
    DateCrea DATETIME DEFAULT NULL COMMENT 'Date de création',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Créé/modifié par',
    PRIMARY KEY (id),
    UNIQUE KEY uk_numprojet (NumProjet),
    KEY idx_statut (Statut),
    KEY fk_createur (fkCreateur),
    CONSTRAINT fk_projet_createur FOREIGN KEY (fkCreateur)
        REFERENCES tb_Utilisateur(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Table des projets';

-- -----------------------------------------------------------------------------
-- Table : tb_Version
-- Description : Versions d'un projet (permet le versioning)
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Version (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    fkProjet INT(11) NOT NULL COMMENT 'FK vers le projet parent',
    NumVersion INT(11) NOT NULL COMMENT 'Numéro de version (par projet)',
    Libelle VARCHAR(200) DEFAULT NULL COMMENT 'Libellé de la version',
    Description TEXT DEFAULT NULL COMMENT 'Notes sur cette version',
    Statut ENUM('BROUILLON', 'VALIDE', 'ARCHIVE') NOT NULL DEFAULT 'BROUILLON' COMMENT 'Statut',
    fkUtilisateur INT(11) DEFAULT NULL COMMENT 'Dernier utilisateur ayant modifié',
    DateValidation DATETIME DEFAULT NULL COMMENT 'Date de validation',
    DateCrea DATETIME DEFAULT NULL COMMENT 'Date de création',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Créé/modifié par',
    PRIMARY KEY (id),
    UNIQUE KEY uk_projet_version (fkProjet, NumVersion),
    KEY idx_statut (Statut),
    KEY fk_utilisateur (fkUtilisateur),
    CONSTRAINT fk_version_projet FOREIGN KEY (fkProjet)
        REFERENCES tb_Projet(id) ON DELETE CASCADE,
    CONSTRAINT fk_version_utilisateur FOREIGN KEY (fkUtilisateur)
        REFERENCES tb_Utilisateur(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Versions d''un projet';

-- -----------------------------------------------------------------------------
-- Table : tb_Client
-- Description : Clients associés à une version
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Client (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    fkVersion INT(11) NOT NULL COMMENT 'FK vers la version parente',
    Code VARCHAR(20) NOT NULL COMMENT 'Code client',
    RaisonSociale VARCHAR(200) NOT NULL COMMENT 'Raison sociale',
    Adresse VARCHAR(500) DEFAULT NULL COMMENT 'Adresse complète',
    CodePostal VARCHAR(10) DEFAULT NULL COMMENT 'Code postal',
    Ville VARCHAR(100) DEFAULT NULL COMMENT 'Ville',
    Pays VARCHAR(100) DEFAULT 'France' COMMENT 'Pays',
    Telephone VARCHAR(20) DEFAULT NULL COMMENT 'Téléphone',
    Email VARCHAR(200) DEFAULT NULL COMMENT 'Email',
    Contact VARCHAR(200) DEFAULT NULL COMMENT 'Nom du contact',
    Actif TINYINT(4) NOT NULL DEFAULT 1 COMMENT '1=actif, 0=inactif',
    DateCrea DATETIME DEFAULT NULL COMMENT 'Date de création',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Créé/modifié par',
    PRIMARY KEY (id),
    UNIQUE KEY uk_version_code (fkVersion, Code),
    KEY idx_raison_sociale (RaisonSociale),
    CONSTRAINT fk_client_version FOREIGN KEY (fkVersion)
        REFERENCES tb_Version(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Clients d''une version';

-- -----------------------------------------------------------------------------
-- Table : tb_Commande
-- Description : Commandes d'un client
-- -----------------------------------------------------------------------------
CREATE TABLE tb_Commande (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    fkClient INT(11) NOT NULL COMMENT 'FK vers le client',
    NumCommande VARCHAR(50) NOT NULL COMMENT 'Numéro de commande',
    DateCommande DATE NOT NULL COMMENT 'Date de la commande',
    DateLivraison DATE DEFAULT NULL COMMENT 'Date de livraison prévue',
    Statut ENUM('EN_ATTENTE', 'VALIDEE', 'EN_COURS', 'LIVREE', 'ANNULEE')
        NOT NULL DEFAULT 'EN_ATTENTE' COMMENT 'Statut de la commande',
    MontantHT DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Montant HT calculé',
    TauxTVA DECIMAL(5,2) DEFAULT 20.00 COMMENT 'Taux de TVA',
    MontantTTC DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Montant TTC calculé',
    Remise DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Remise en pourcentage',
    Notes TEXT DEFAULT NULL COMMENT 'Notes sur la commande',
    DateCrea DATETIME DEFAULT NULL COMMENT 'Date de création',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Créé/modifié par',
    PRIMARY KEY (id),
    UNIQUE KEY uk_client_numcommande (fkClient, NumCommande),
    KEY idx_date_commande (DateCommande),
    KEY idx_statut (Statut),
    CONSTRAINT fk_commande_client FOREIGN KEY (fkClient)
        REFERENCES tb_Client(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Commandes des clients';

-- -----------------------------------------------------------------------------
-- Table : tb_LigneCommande
-- Description : Lignes de détail d'une commande
-- -----------------------------------------------------------------------------
CREATE TABLE tb_LigneCommande (
    id INT(11) NOT NULL AUTO_INCREMENT COMMENT 'Identifiant unique',
    fkCommande INT(11) NOT NULL COMMENT 'FK vers la commande',
    NumLigne INT(11) NOT NULL COMMENT 'Numéro de ligne',
    Reference VARCHAR(50) NOT NULL COMMENT 'Référence article',
    Designation VARCHAR(500) NOT NULL COMMENT 'Désignation',
    Quantite DECIMAL(15,3) NOT NULL DEFAULT 1.000 COMMENT 'Quantité',
    Unite VARCHAR(20) DEFAULT 'U' COMMENT 'Unité',
    PrixUnitaire DECIMAL(15,4) NOT NULL DEFAULT 0.0000 COMMENT 'Prix unitaire HT',
    Remise DECIMAL(5,2) DEFAULT 0.00 COMMENT 'Remise ligne en %',
    MontantHT DECIMAL(15,2) DEFAULT 0.00 COMMENT 'Montant HT ligne',
    DateCrea DATETIME DEFAULT NULL COMMENT 'Date de création',
    DateModif DATETIME DEFAULT NULL COMMENT 'Date de dernière modification',
    ParQui VARCHAR(100) DEFAULT NULL COMMENT 'Créé/modifié par',
    PRIMARY KEY (id),
    UNIQUE KEY uk_commande_ligne (fkCommande, NumLigne),
    KEY idx_reference (Reference),
    CONSTRAINT fk_ligne_commande FOREIGN KEY (fkCommande)
        REFERENCES tb_Commande(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Lignes de commande';

-- =============================================================================
-- SECTION 4 : Données initiales
-- =============================================================================

-- Insertion des compteurs
INSERT INTO tb_Compteur (TypeCompteur, Prefixe, ValeurActuelle, DateModif) VALUES
('PROJET', 'PRJ', 0, NOW()),
('VERSION', 'VER', 0, NOW()),
('CLIENT', 'CLI', 0, NOW()),
('COMMANDE', 'CMD', 0, NOW());

-- Insertion d'un utilisateur de test
INSERT INTO tb_Utilisateur (Login, Nom, Email, Actif, DateCrea, ParQui) VALUES
('admin', 'Administrateur Système', 'admin@test.com', 1, NOW(), 'SYSTEM'),
('user1', 'Utilisateur Test 1', 'user1@test.com', 1, NOW(), 'SYSTEM'),
('user2', 'Utilisateur Test 2', 'user2@test.com', 1, NOW(), 'SYSTEM');

-- =============================================================================
-- SECTION 5 : Vues utiles
-- =============================================================================

-- Vue récapitulative des projets avec leurs versions
CREATE OR REPLACE VIEW v_ProjetVersions AS
SELECT
    p.id AS ProjetId,
    p.NumProjet,
    p.Libelle AS ProjetLibelle,
    p.Statut AS ProjetStatut,
    COUNT(v.id) AS NbVersions,
    MAX(v.NumVersion) AS DerniereVersion
FROM tb_Projet p
LEFT JOIN tb_Version v ON p.id = v.fkProjet
GROUP BY p.id, p.NumProjet, p.Libelle, p.Statut;

-- Vue récapitulative des commandes
CREATE OR REPLACE VIEW v_CommandesRecap AS
SELECT
    c.id AS CommandeId,
    c.NumCommande,
    c.DateCommande,
    c.Statut,
    cl.RaisonSociale AS Client,
    COUNT(l.id) AS NbLignes,
    SUM(l.MontantHT) AS TotalHT
FROM tb_Commande c
JOIN tb_Client cl ON c.fkClient = cl.id
LEFT JOIN tb_LigneCommande l ON c.id = l.fkCommande
GROUP BY c.id, c.NumCommande, c.DateCommande, c.Statut, cl.RaisonSociale;

-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================

SELECT 'Schéma de base de données créé avec succès !' AS Message;
