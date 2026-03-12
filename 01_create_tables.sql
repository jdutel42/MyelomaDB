-- ============================================================
-- BIOBANQUE CLINIQUE - Schéma PostgreSQL
-- Script 01 : Création des tables
-- ============================================================

-- Extension pour UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE : patients
-- ============================================================
CREATE TABLE IF NOT EXISTS patients (
    patient_id      VARCHAR(12) PRIMARY KEY,          -- ex: PAT-2024-0001
    date_naissance  DATE NOT NULL,
    sexe            CHAR(1) CHECK (sexe IN ('M','F','A')),  -- M/F/Autre
    groupe_sanguin  VARCHAR(3),
    ethnie          VARCHAR(50),
    consentement    BOOLEAN DEFAULT TRUE,
    date_inclusion  DATE NOT NULL,
    protocole_id    VARCHAR(20),
    centre_id       VARCHAR(10),
    statut          VARCHAR(20) DEFAULT 'actif' CHECK (statut IN ('actif','perdu_de_vue','décédé','retiré')),
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TABLE : protocoles
-- ============================================================
CREATE TABLE IF NOT EXISTS protocoles (
    protocole_id    VARCHAR(20) PRIMARY KEY,
    nom             VARCHAR(200) NOT NULL,
    description     TEXT,
    date_debut      DATE,
    date_fin        DATE,
    responsable     VARCHAR(100),
    statut          VARCHAR(20) DEFAULT 'actif'
);

-- ============================================================
-- TABLE : prelevements
-- ============================================================
CREATE TABLE IF NOT EXISTS prelevements (
    prelevement_id  VARCHAR(16) PRIMARY KEY,          -- ex: PRE-20240115-001
    patient_id      VARCHAR(12) REFERENCES patients(patient_id) ON DELETE CASCADE,
    date_prelevement TIMESTAMP NOT NULL,
    type_prelevement VARCHAR(30) CHECK (type_prelevement IN (
        'sang_total','serum','plasma','urine','salive',
        'LCR','biopsie','ADN','ARN','autre'
    )),
    volume_ml       NUMERIC(8,3),
    tube_type       VARCHAR(30),                      -- EDTA, héparine, SST...
    operateur       VARCHAR(100),
    temperature_stockage NUMERIC(5,1),               -- °C
    localisation    VARCHAR(50),                      -- ex: Congélateur-A / Rack-3 / Box-12
    qualite         VARCHAR(20) DEFAULT 'bonne' CHECK (qualite IN ('bonne','acceptable','degradee','rejetee')),
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TABLE : biomarqueurs_numeriques
-- ============================================================
CREATE TABLE IF NOT EXISTS biomarqueurs_numeriques (
    mesure_id       SERIAL PRIMARY KEY,
    prelevement_id  VARCHAR(16) REFERENCES prelevements(prelevement_id) ON DELETE CASCADE,
    patient_id      VARCHAR(12) REFERENCES patients(patient_id),
    date_mesure     TIMESTAMP NOT NULL,
    biomarqueur     VARCHAR(50) NOT NULL,             -- ex: CRP, IL6, HbA1c...
    valeur          NUMERIC(12,4) NOT NULL,
    unite           VARCHAR(20),                      -- mg/L, pg/mL, %...
    methode         VARCHAR(100),
    appareil        VARCHAR(100),
    operateur       VARCHAR(100),
    valeur_ref_min  NUMERIC(12,4),
    valeur_ref_max  NUMERIC(12,4),
    hors_norme      BOOLEAN GENERATED ALWAYS AS (
        valeur < valeur_ref_min OR valeur > valeur_ref_max
    ) STORED,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TABLE : biomarqueurs_qualitatifs
-- ============================================================
CREATE TABLE IF NOT EXISTS biomarqueurs_qualitatifs (
    mesure_id       SERIAL PRIMARY KEY,
    prelevement_id  VARCHAR(16) REFERENCES prelevements(prelevement_id) ON DELETE CASCADE,
    patient_id      VARCHAR(12) REFERENCES patients(patient_id),
    date_mesure     TIMESTAMP NOT NULL,
    biomarqueur     VARCHAR(50) NOT NULL,             -- ex: statut_HPV, mutation_BRCA...
    resultat        VARCHAR(100) NOT NULL,            -- positif/négatif, muté/sauvage...
    methode         VARCHAR(100),
    operateur       VARCHAR(100),
    notes           TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TABLE : evenements_cliniques
-- ============================================================
CREATE TABLE IF NOT EXISTS evenements_cliniques (
    evenement_id    SERIAL PRIMARY KEY,
    patient_id      VARCHAR(12) REFERENCES patients(patient_id) ON DELETE CASCADE,
    date_evenement  DATE NOT NULL,
    type_evenement  VARCHAR(50),                      -- hospitalisation, recidive, deces...
    description     TEXT,
    severite        VARCHAR(20) CHECK (severite IN ('faible','modérée','sévère','critique')),
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TABLE : utilisateurs (multi-user simple)
-- ============================================================
CREATE TABLE IF NOT EXISTS utilisateurs (
    user_id         SERIAL PRIMARY KEY,
    login           VARCHAR(50) UNIQUE NOT NULL,
    nom             VARCHAR(100),
    role            VARCHAR(20) DEFAULT 'lecteur' CHECK (role IN ('admin','chercheur','technicien','lecteur')),
    actif           BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- TABLE : audit_log (traçabilité)
-- ============================================================
CREATE TABLE IF NOT EXISTS audit_log (
    log_id          SERIAL PRIMARY KEY,
    table_name      VARCHAR(50),
    operation       VARCHAR(10),                      -- INSERT/UPDATE/DELETE
    record_id       VARCHAR(50),
    user_login      VARCHAR(50),
    ancien_valeur   JSONB,
    nouvelle_valeur JSONB,
    timestamp       TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- INDEX pour les requêtes fréquentes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_prelevements_patient ON prelevements(patient_id);
CREATE INDEX IF NOT EXISTS idx_prelevements_date ON prelevements(date_prelevement);
CREATE INDEX IF NOT EXISTS idx_bm_num_patient ON biomarqueurs_numeriques(patient_id);
CREATE INDEX IF NOT EXISTS idx_bm_num_biomarqueur ON biomarqueurs_numeriques(biomarqueur);
CREATE INDEX IF NOT EXISTS idx_bm_qual_patient ON biomarqueurs_qualitatifs(patient_id);
CREATE INDEX IF NOT EXISTS idx_evenements_patient ON evenements_cliniques(patient_id);

-- ============================================================
-- VUE synthétique patients + biomarqueurs récents
-- ============================================================
CREATE OR REPLACE VIEW vue_patients_resume AS
SELECT
    p.patient_id,
    DATE_PART('year', AGE(p.date_naissance))::INT AS age,
    p.sexe,
    p.groupe_sanguin,
    p.statut,
    p.protocole_id,
    COUNT(DISTINCT pr.prelevement_id) AS nb_prelevements,
    MAX(pr.date_prelevement)::DATE   AS dernier_prelevement,
    COUNT(DISTINCT bn.mesure_id)     AS nb_mesures_num,
    COUNT(DISTINCT bq.mesure_id)     AS nb_mesures_qual
FROM patients p
LEFT JOIN prelevements pr       ON pr.patient_id = p.patient_id
LEFT JOIN biomarqueurs_numeriques bn ON bn.patient_id = p.patient_id
LEFT JOIN biomarqueurs_qualitatifs bq ON bq.patient_id = p.patient_id
GROUP BY p.patient_id, p.date_naissance, p.sexe, p.groupe_sanguin, p.statut, p.protocole_id;

-- Confirmation
SELECT 'Schema biobanque créé avec succès ✓' AS status;
