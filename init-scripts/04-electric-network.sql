-- ============================================================
-- 04-electric-network.sql
-- Tables du réseau électrique avec labels multilingues et code_geo
-- Version complète intégrant tout le modèle
-- ============================================================

SET search_path TO electrique, metier, iot, public;

-- ============================================================
-- 1. SCHÉMA ELECTRIQUE - TABLES DE RÉFÉRENCE
-- ============================================================

-- Catalogue des types d'assets (évolutif)
CREATE TABLE electrique.AssetTypeCatalog (
    asset_type_code   VARCHAR(50) PRIMARY KEY,
    domain            VARCHAR(50) NOT NULL,   -- 'Electric', 'Structure', 'Gas', etc.
    asset_group       VARCHAR(50) NOT NULL,
    asset_type        VARCHAR(50) NOT NULL,
    tier              SMALLINT,               -- 1..4 pour électrique
    description       TEXT,
    -- Labels multilingues
    label_fr          VARCHAR(255),           -- Libellé en français
    label_ar          VARCHAR(255),           -- Libellé en arabe
    label_default     VARCHAR(255),           -- Libellé par défaut (anglais)
    created_date      TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE electrique.AssetTypeCatalog IS 'Catalogue des types d''actifs';
COMMENT ON COLUMN electrique.AssetTypeCatalog.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.AssetTypeCatalog.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.AssetTypeCatalog.label_default IS 'Libellé par défaut (anglais)';

-- Table d'attributs génériques (clé-valeur par asset)
CREATE TABLE electrique.AssetAttribute (
    attribute_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_class       VARCHAR(50) NOT NULL,   -- nom de la table métier
    asset_globalid    UUID NOT NULL,
    attribute_name    VARCHAR(100) NOT NULL,
    attribute_value   TEXT,
    unit              VARCHAR(20),
    -- Labels multilingues
    label_fr          VARCHAR(255),
    label_ar          VARCHAR(255),
    label_default     VARCHAR(255),
    recorded_date     TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE electrique.AssetAttribute IS 'Attributs génériques des actifs';
COMMENT ON COLUMN electrique.AssetAttribute.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.AssetAttribute.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.AssetAttribute.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 2. SCHÉMA ELECTRIQUE - STRUCTURE NETWORK (partagé, générique)
-- ============================================================

CREATE TABLE electrique.StructureLine (
    globalid            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assetgroup          VARCHAR(50) NOT NULL,
    assettype           VARCHAR(50) NOT NULL,
    operationalstatus   VARCHAR(20) NOT NULL,
    lifecycle           VARCHAR(20) NOT NULL,
    validfrom           TIMESTAMP NOT NULL,
    validto             TIMESTAMP,
    owner               VARCHAR(100),
    material            VARCHAR(50),
    capacity_volume     DOUBLE PRECISION,
    width_m             DOUBLE PRECISION,
    height_m            DOUBLE PRECISION,
    installation_method VARCHAR(30),   -- 'Underground_Duct', 'OpenTrench', etc.
    burial_depth_cm     INTEGER,
    shape               GEOMETRY(LineString, 2154), -- SRID adapté
    -- Code géographique (format: SXXXXYYYY)
    code_geo            VARCHAR(10) UNIQUE,        -- Code géographique de la localité
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    created_date        TIMESTAMP DEFAULT NOW(),
    modified_date       TIMESTAMP DEFAULT NOW(),
    responsibiliteam    VARCHAR(100),
    last_maintenance    DATE,
    created_by          UUID,
    modified_by         UUID,
    CHECK (validto IS NULL OR validto >= validfrom)
);

COMMENT ON TABLE electrique.StructureLine IS 'Infrastructures linéaires partagées : fourreaux, canaux, tranchées';
COMMENT ON COLUMN electrique.StructureLine.code_geo IS 'Code géographique (format: SXXXXYYYY) avec S=0 pour Est, S=9 pour Ouest';
COMMENT ON COLUMN electrique.StructureLine.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.StructureLine.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.StructureLine.label_default IS 'Libellé par défaut (anglais)';

CREATE TABLE electrique.StructureJunction (
    globalid            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assetgroup          VARCHAR(50) NOT NULL,
    assettype           VARCHAR(50) NOT NULL,
    operationalstatus   VARCHAR(20) NOT NULL,
    lifecycle           VARCHAR(20) NOT NULL,
    validfrom           TIMESTAMP NOT NULL,
    validto             TIMESTAMP,
    owner               VARCHAR(100),
    material            VARCHAR(50),
    height_m            DOUBLE PRECISION,
    ground_clearance_m  DOUBLE PRECISION,
    load_capacity_kg    DOUBLE PRECISION,
    shape               GEOMETRY(Point, 2154),
    -- Code géographique (format: SXXXXYYYY)
    code_geo            VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    created_date        TIMESTAMP DEFAULT NOW(),
    modified_date       TIMESTAMP DEFAULT NOW(),
    responsibiliteam    VARCHAR(100),
    created_by          UUID,
    modified_by         UUID,
    CHECK (validto IS NULL OR validto >= validfrom)
);

COMMENT ON TABLE electrique.StructureJunction IS 'Points nodaux : poteaux, regards, chambres';
COMMENT ON COLUMN electrique.StructureJunction.code_geo IS 'Code géographique (format: SXXXXYYYY)';
COMMENT ON COLUMN electrique.StructureJunction.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.StructureJunction.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.StructureJunction.label_default IS 'Libellé par défaut (anglais)';

CREATE TABLE electrique.StructureAssembly (
    assembly_globalid   UUID NOT NULL,
    assembly_name       VARCHAR(100) NOT NULL,
    component_globalid  UUID NOT NULL,
    component_role      VARCHAR(50),
    quantity            INTEGER DEFAULT 1,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    created_by          UUID,
    created_date        TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (assembly_globalid, component_globalid)
);

COMMENT ON TABLE electrique.StructureAssembly IS 'Assemblages de structures (ex: pylône composite)';
COMMENT ON COLUMN electrique.StructureAssembly.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.StructureAssembly.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.StructureAssembly.label_default IS 'Libellé par défaut (anglais)';

CREATE TABLE electrique.StructureBoundary (
    globalid            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    boundary_type       VARCHAR(30) NOT NULL,
    name                VARCHAR(100),
    owner               VARCHAR(100),
    shape               GEOMETRY(Polygon, 2154),
    -- Code géographique (format: SXXXXYYYY)
    code_geo            VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    created_date        TIMESTAMP DEFAULT NOW(),
    created_by          UUID
);

COMMENT ON TABLE electrique.StructureBoundary IS 'Zones administratives ou d''emprise';
COMMENT ON COLUMN electrique.StructureBoundary.code_geo IS 'Code géographique (format: SXXXXYYYY)';
COMMENT ON COLUMN electrique.StructureBoundary.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.StructureBoundary.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.StructureBoundary.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 3. SCHÉMA ELECTRIQUE - DOMAIN NETWORK ÉLECTRICITÉ
-- ============================================================

CREATE TABLE electrique.ElectricLine (
    globalid               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assetgroup             VARCHAR(50) NOT NULL,
    assettype              VARCHAR(50) NOT NULL,
    tier                   SMALLINT NOT NULL CHECK (tier BETWEEN 1 AND 4),
    operationalstatus      VARCHAR(20) NOT NULL,
    lifecycle              VARCHAR(20) NOT NULL,
    validfrom              TIMESTAMP NOT NULL,
    validto                TIMESTAMP,
    owner                  VARCHAR(100),
    responsibiliteam       VARCHAR(100),
    installation_method    VARCHAR(30) CHECK (installation_method IN ('Overhead','Underground_DirectBurial','Underground_Duct','Submarine','Indoor')),
    conductor_type         VARCHAR(30),
    cross_section_mm2      DOUBLE PRECISION,
    rated_voltage_kv       DOUBLE PRECISION,
    rated_current_a        DOUBLE PRECISION,
    length_m               DOUBLE PRECISION,
    impedance_ohm_per_km   DOUBLE PRECISION,
    burial_depth_cm        INTEGER,
    protection_type        VARCHAR(30),
    location_marker        VARCHAR(30),
    tower_type             VARCHAR(30),
    sag_m                  DOUBLE PRECISION,
    ground_clearance_m     DOUBLE PRECISION,
    shape                  GEOMETRY(LineString, 2154),
    -- Code géographique (format: SXXXXYYYY)
    code_geo               VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr               VARCHAR(255),
    label_ar               VARCHAR(255),
    label_default          VARCHAR(255),
    -- Type de localité administratif
    localite_type          VARCHAR(30),  -- 'VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'
    code_adm               VARCHAR(50),   -- Code administratif de la localité
    created_date           TIMESTAMP DEFAULT NOW(),
    modified_date          TIMESTAMP DEFAULT NOW(),
    last_maintenance       DATE,
    created_by             UUID,
    modified_by            UUID,
    CHECK (validto IS NULL OR validto >= validfrom),
    CHECK (localite_type IN ('VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'))
);

COMMENT ON TABLE electrique.ElectricLine IS 'Lignes électriques (aériennes, souterraines, sous-marines)';
COMMENT ON COLUMN electrique.ElectricLine.code_geo IS 'Code géographique (format: SXXXXYYYY) avec S=0 pour Est, S=9 pour Ouest';
COMMENT ON COLUMN electrique.ElectricLine.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.ElectricLine.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.ElectricLine.label_default IS 'Libellé par défaut (anglais)';
COMMENT ON COLUMN electrique.ElectricLine.localite_type IS 'Type de localité : VILLE, COMMUNE, VILLAGE, HAMEAU, CAMPEMENT';
COMMENT ON COLUMN electrique.ElectricLine.code_adm IS 'Code administratif de la localité';

CREATE TABLE electrique.ElectricDevice (
    globalid                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assetgroup              VARCHAR(50) NOT NULL,
    assettype               VARCHAR(50) NOT NULL,
    tier                    SMALLINT NOT NULL CHECK (tier BETWEEN 1 AND 4),
    operationalstatus       VARCHAR(20) NOT NULL,
    lifecycle               VARCHAR(20) NOT NULL,
    validfrom               TIMESTAMP NOT NULL,
    validto                 TIMESTAMP,
    owner                   VARCHAR(100),
    responsibiliteam        VARCHAR(100),
    installation_method     VARCHAR(30),
    capacity_kva            DOUBLE PRECISION CHECK (capacity_kva >= 0),
    inservice_load_kva      DOUBLE PRECISION,
    coolingsystem           VARCHAR(20),
    taplevel                INTEGER,
    manufacturer            VARCHAR(100),
    serialnumber            VARCHAR(100),
    model_ref               VARCHAR(100),
    efficiency_percent      DOUBLE PRECISION,
    winding1_voltage_kv     DOUBLE PRECISION,
    winding2_voltage_kv     DOUBLE PRECISION,
    rated_current_a         DOUBLE PRECISION,
    predictivemaint_flag    BOOLEAN DEFAULT FALSE,
    shape                   GEOMETRY(Point, 2154),
    -- Code géographique (format: SXXXXYYYY)
    code_geo                VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr                VARCHAR(255),
    label_ar                VARCHAR(255),
    label_default           VARCHAR(255),
    -- Type de localité administratif
    localite_type           VARCHAR(30),  -- 'VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'
    code_adm                VARCHAR(50),   -- Code administratif de la localité
    created_date            TIMESTAMP DEFAULT NOW(),
    modified_date           TIMESTAMP DEFAULT NOW(),
    last_maintenance        DATE,
    created_by              UUID,
    modified_by             UUID,
    CHECK (validto IS NULL OR validto >= validfrom),
    CHECK (localite_type IN ('VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'))
);

COMMENT ON TABLE electrique.ElectricDevice IS 'Équipements électriques actifs (transformateurs, disjoncteurs, compteurs)';
COMMENT ON COLUMN electrique.ElectricDevice.code_geo IS 'Code géographique (format: SXXXXYYYY)';
COMMENT ON COLUMN electrique.ElectricDevice.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.ElectricDevice.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.ElectricDevice.label_default IS 'Libellé par défaut (anglais)';
COMMENT ON COLUMN electrique.ElectricDevice.localite_type IS 'Type de localité : VILLE, COMMUNE, VILLAGE, HAMEAU, CAMPEMENT';
COMMENT ON COLUMN electrique.ElectricDevice.code_adm IS 'Code administratif de la localité';

CREATE TABLE electrique.ElectricAssembly (
    assembly_globalid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assetgroup          VARCHAR(30) NOT NULL,
    assettype           VARCHAR(50) NOT NULL,
    name                VARCHAR(100),
    operationalstatus   VARCHAR(20) NOT NULL,
    lifecycle           VARCHAR(20) NOT NULL,
    validfrom           TIMESTAMP NOT NULL,
    validto             TIMESTAMP,
    owner               VARCHAR(100),
    gis_link            TEXT,
    -- Code géographique (format: SXXXXYYYY)
    code_geo            VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    -- Type de localité administratif
    localite_type       VARCHAR(30),  -- 'VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'
    code_adm            VARCHAR(50),   -- Code administratif de la localité
    created_date        TIMESTAMP DEFAULT NOW(),
    created_by          UUID,
    CHECK (validto IS NULL OR validto >= validfrom),
    CHECK (localite_type IN ('VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'))
);

COMMENT ON TABLE electrique.ElectricAssembly IS 'Postes, sous-stations, groupements d''équipements';
COMMENT ON COLUMN electrique.ElectricAssembly.code_geo IS 'Code géographique (format: SXXXXYYYY)';
COMMENT ON COLUMN electrique.ElectricAssembly.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.ElectricAssembly.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.ElectricAssembly.label_default IS 'Libellé par défaut (anglais)';
COMMENT ON COLUMN electrique.ElectricAssembly.localite_type IS 'Type de localité';
COMMENT ON COLUMN electrique.ElectricAssembly.code_adm IS 'Code administratif de la localité';

-- Table de liaison Assemblage ↔ Dispositif
CREATE TABLE electrique.AssemblyContent (
    assembly_globalid   UUID REFERENCES electrique.ElectricAssembly(assembly_globalid) ON DELETE CASCADE,
    device_globalid     UUID REFERENCES electrique.ElectricDevice(globalid) ON DELETE CASCADE,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    PRIMARY KEY (assembly_globalid, device_globalid)
);

COMMENT ON TABLE electrique.AssemblyContent IS 'Liaison entre assemblages et dispositifs';
COMMENT ON COLUMN electrique.AssemblyContent.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.AssemblyContent.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.AssemblyContent.label_default IS 'Libellé par défaut (anglais)';

CREATE TABLE electrique.ElectricJunctionObject (
    globalid              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_device_globalid UUID NOT NULL REFERENCES electrique.ElectricDevice(globalid) ON DELETE CASCADE,
    terminal_name         VARCHAR(20) NOT NULL,
    terminal_number       INTEGER,
    -- Labels multilingues
    label_fr              VARCHAR(255),
    label_ar              VARCHAR(255),
    label_default         VARCHAR(255)
);

COMMENT ON TABLE electrique.ElectricJunctionObject IS 'Points de connexion internes aux équipements (bornes)';
COMMENT ON COLUMN electrique.ElectricJunctionObject.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.ElectricJunctionObject.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.ElectricJunctionObject.label_default IS 'Libellé par défaut (anglais)';

CREATE TABLE electrique.ElectricEdgeObject (
    globalid              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assembly_globalid     UUID REFERENCES electrique.ElectricAssembly(assembly_globalid) ON DELETE CASCADE,
    conductor_material    VARCHAR(20),
    cross_section_mm2     DOUBLE PRECISION,
    -- Labels multilingues
    label_fr              VARCHAR(255),
    label_ar              VARCHAR(255),
    label_default         VARCHAR(255)
);

COMMENT ON TABLE electrique.ElectricEdgeObject IS 'Câbles internes aux assemblages (barres, bus)';
COMMENT ON COLUMN electrique.ElectricEdgeObject.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.ElectricEdgeObject.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.ElectricEdgeObject.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 4. SCHÉMA ELECTRIQUE - TABLES D'ASSOCIATION
-- ============================================================

-- 4.1 Contenu des fourreaux (câbles dans structure)
CREATE TABLE electrique.StructureContent (
    content_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    structure_globalid  UUID NOT NULL REFERENCES electrique.StructureLine(globalid) ON DELETE CASCADE,
    asset_globalid      UUID NOT NULL,
    occupancy_ratio     DOUBLE PRECISION CHECK (occupancy_ratio BETWEEN 0 AND 100),
    start_measure       DOUBLE PRECISION,
    end_measure         DOUBLE PRECISION,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255)
);

COMMENT ON TABLE electrique.StructureContent IS 'Association câbles ↔ fourreaux (multi-réseaux)';
COMMENT ON COLUMN electrique.StructureContent.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.StructureContent.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.StructureContent.label_default IS 'Libellé par défaut (anglais)';

-- 4.2 Fixation d'équipement sur structure
CREATE TABLE electrique.StructuralAttachment (
    attachment_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    structure_globalid  UUID NOT NULL,
    equipment_globalid  UUID NOT NULL REFERENCES electrique.ElectricDevice(globalid) ON DELETE CASCADE,
    attachment_point    VARCHAR(30),
    offset_distance_m   DOUBLE PRECISION,
    orientation_degrees DOUBLE PRECISION,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255)
);

COMMENT ON TABLE electrique.StructuralAttachment IS 'Fixation des équipements sur les structures (poteaux, murs)';
COMMENT ON COLUMN electrique.StructuralAttachment.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.StructuralAttachment.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.StructuralAttachment.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 5. SCHÉMA ELECTRIQUE - LOG DES ERREURS TOPOLOGIQUES
-- ============================================================

CREATE TABLE electrique.TopologyErrorLog (
    error_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    error_type          VARCHAR(50),
    feature_class       VARCHAR(50),
    feature_globalid    UUID,
    error_description   TEXT,
    detected_timestamp  TIMESTAMP DEFAULT NOW(),
    resolved_timestamp  TIMESTAMP,
    resolved_by         VARCHAR(100),
    created_by          UUID,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    CHECK (resolved_timestamp IS NULL OR resolved_timestamp >= detected_timestamp)
);

COMMENT ON TABLE electrique.TopologyErrorLog IS 'Journal des erreurs de topologie réseau';
COMMENT ON COLUMN electrique.TopologyErrorLog.label_fr IS 'Libellé en français';
COMMENT ON COLUMN electrique.TopologyErrorLog.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN electrique.TopologyErrorLog.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 6. SCHÉMA METIER - PANNES
-- ============================================================

CREATE TABLE metier.OutageLog (
    outage_id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outage_starttime          TIMESTAMP NOT NULL,
    outage_endtime            TIMESTAMP,
    affected_feature_class    VARCHAR(50) NOT NULL,
    affected_feature_globalid UUID NOT NULL,
    root_cause_category       VARCHAR(50),
    root_cause_detail         TEXT,
    impacted_customer_count   INTEGER,
    impacted_demand_mw        DOUBLE PRECISION,
    duration_minutes          INTEGER GENERATED ALWAYS AS (EXTRACT(EPOCH FROM (outage_endtime - outage_starttime))/60) STORED,
    resolution_team           VARCHAR(100),
    incident_report_link      TEXT,
    -- Labels multilingues
    label_fr                  VARCHAR(255),
    label_ar                  VARCHAR(255),
    label_default             VARCHAR(255),
    created_date              TIMESTAMP DEFAULT NOW(),
    created_by                UUID,
    CHECK (outage_endtime IS NULL OR outage_endtime >= outage_starttime)
);

COMMENT ON TABLE metier.OutageLog IS 'Journal des pannes électriques';
COMMENT ON COLUMN metier.OutageLog.label_fr IS 'Libellé en français';
COMMENT ON COLUMN metier.OutageLog.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN metier.OutageLog.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 7. SCHÉMA METIER - CLIENTS
-- ============================================================

CREATE TABLE metier.CustomerAccount (
    customer_id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name             VARCHAR(150) NOT NULL,
    service_point_globalid    UUID NOT NULL,
    meter_installation_date   DATE,
    voltage_class             VARCHAR(30),
    billing_status            VARCHAR(30),
    actual_consumption_kwh    DOUBLE PRECISION,
    estimated_annual_kwh      DOUBLE PRECISION,
    outage_history_count      INTEGER DEFAULT 0,
    last_outage_date          DATE,
    contact_email             VARCHAR(150),
    contact_phone             VARCHAR(50),
    -- Code géographique (format: SXXXXYYYY)
    code_geo                  VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr                  VARCHAR(255),
    label_ar                  VARCHAR(255),
    label_default             VARCHAR(255),
    -- Type de localité administratif
    localite_type             VARCHAR(30),  -- 'VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'
    code_adm                  VARCHAR(50),   -- Code administratif de la localité
    created_date              TIMESTAMP DEFAULT NOW(),
    modified_date             TIMESTAMP DEFAULT NOW(),
    created_by                UUID,
    modified_by               UUID,
    CHECK (localite_type IN ('VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'))
);

COMMENT ON TABLE metier.CustomerAccount IS 'Comptes clients et points de livraison';
COMMENT ON COLUMN metier.CustomerAccount.code_geo IS 'Code géographique (format: SXXXXYYYY)';
COMMENT ON COLUMN metier.CustomerAccount.label_fr IS 'Libellé en français';
COMMENT ON COLUMN metier.CustomerAccount.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN metier.CustomerAccount.label_default IS 'Libellé par défaut (anglais)';
COMMENT ON COLUMN metier.CustomerAccount.localite_type IS 'Type de localité';
COMMENT ON COLUMN metier.CustomerAccount.code_adm IS 'Code administratif de la localité';

-- ============================================================
-- 8. SCHÉMA METIER - INTERVENTIONS
-- ============================================================

CREATE TABLE metier.InterventionLog (
    intervention_id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id             VARCHAR(50) UNIQUE NOT NULL,
    intervention_type         VARCHAR(50),
    affected_feature_class    VARCHAR(50) NOT NULL,
    affected_feature_globalid UUID NOT NULL,
    scheduled_date            DATE,
    actual_start_date         TIMESTAMP,
    actual_end_date           TIMESTAMP,
    duration_hours            DOUBLE PRECISION GENERATED ALWAYS AS (EXTRACT(EPOCH FROM (actual_end_date - actual_start_date))/3600) STORED,
    status                    VARCHAR(20),
    technician_name           VARCHAR(100),
    technician_team           VARCHAR(100),
    description_work          TEXT,
    downtime_minutes          INTEGER,
    impacted_customers_count  INTEGER,
    parts_cost_usd            DOUBLE PRECISION,
    labor_cost_usd            DOUBLE PRECISION,
    total_cost_usd            DOUBLE PRECISION GENERATED ALWAYS AS (COALESCE(parts_cost_usd,0) + COALESCE(labor_cost_usd,0)) STORED,
    weather_condition         VARCHAR(30),
    photo_attachments         JSONB,
    -- Labels multilingues
    label_fr                  VARCHAR(255),
    label_ar                  VARCHAR(255),
    label_default             VARCHAR(255),
    created_date              TIMESTAMP DEFAULT NOW(),
    created_by                UUID,
    CHECK (actual_end_date IS NULL OR actual_end_date >= actual_start_date)
);

COMMENT ON TABLE metier.InterventionLog IS 'Journal des interventions de maintenance';
COMMENT ON COLUMN metier.InterventionLog.label_fr IS 'Libellé en français';
COMMENT ON COLUMN metier.InterventionLog.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN metier.InterventionLog.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 9. SCHÉMA METIER - DEMANDES DE CONNEXION
-- ============================================================

CREATE TABLE metier.ConnectionRequest (
    request_id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_date                DATE NOT NULL,
    request_type                VARCHAR(30),
    customer_id                 UUID REFERENCES metier.CustomerAccount(customer_id),
    requested_location          GEOMETRY(Point, 2154),
    nearest_service_point_globalid UUID,
    nearest_transformer_distance_m DOUBLE PRECISION,
    status                      VARCHAR(30),
    requested_capacity_kw       DOUBLE PRECISION,
    available_capacity_kw       DOUBLE PRECISION,
    capacity_shortfall_kw       DOUBLE PRECISION,
    upgrade_cost_estimated      DOUBLE PRECISION,
    infrastructure_required     VARCHAR(30),
    lost_revenue_impact_usd     DOUBLE PRECISION,
    priority_level              VARCHAR(15),
    -- Code géographique (format: SXXXXYYYY)
    code_geo                    VARCHAR(10) UNIQUE,
    -- Labels multilingues
    label_fr                    VARCHAR(255),
    label_ar                    VARCHAR(255),
    label_default               VARCHAR(255),
    -- Type de localité administratif
    localite_type               VARCHAR(30),  -- 'VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'
    code_adm                    VARCHAR(50),   -- Code administratif de la localité
    created_date                TIMESTAMP DEFAULT NOW(),
    modified_date               TIMESTAMP DEFAULT NOW(),
    created_by                  UUID,
    modified_by                 UUID,
    CHECK (localite_type IN ('VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT'))
);

COMMENT ON TABLE metier.ConnectionRequest IS 'Demandes de nouveau raccordement ou d''augmentation de puissance';
COMMENT ON COLUMN metier.ConnectionRequest.code_geo IS 'Code géographique (format: SXXXXYYYY)';
COMMENT ON COLUMN metier.ConnectionRequest.label_fr IS 'Libellé en français';
COMMENT ON COLUMN metier.ConnectionRequest.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN metier.ConnectionRequest.label_default IS 'Libellé par défaut (anglais)';
COMMENT ON COLUMN metier.ConnectionRequest.localite_type IS 'Type de localité';
COMMENT ON COLUMN metier.ConnectionRequest.code_adm IS 'Code administratif de la localité';

-- ============================================================
-- 10. SCHÉMA IOT - TÉLÉMÉTRIE
-- ============================================================

CREATE TABLE iot.TelemetryReading (
    reading_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_globalid      UUID NOT NULL,
    timestamp           TIMESTAMP NOT NULL,
    parameter           VARCHAR(30) NOT NULL,
    value               DOUBLE PRECISION,
    unit                VARCHAR(15),
    quality             VARCHAR(20) DEFAULT 'Good',
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255)
);

COMMENT ON TABLE iot.TelemetryReading IS 'Données de télémétrie IoT (courant, tension, puissance, température)';
COMMENT ON COLUMN iot.TelemetryReading.label_fr IS 'Libellé en français';
COMMENT ON COLUMN iot.TelemetryReading.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN iot.TelemetryReading.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 11. SCHÉMA IOT - ALERTES
-- ============================================================

CREATE TABLE iot.Alert (
    alert_id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    asset_globalid      UUID NOT NULL,
    alert_type          VARCHAR(50),
    severity            VARCHAR(10) CHECK (severity IN ('Critical', 'High', 'Medium', 'Low')),
    message             TEXT,
    timestamp           TIMESTAMP DEFAULT NOW(),
    is_acknowledged     BOOLEAN DEFAULT FALSE,
    acknowledged_by     VARCHAR(100),
    cleared_timestamp   TIMESTAMP,
    -- Labels multilingues
    label_fr            VARCHAR(255),
    label_ar            VARCHAR(255),
    label_default       VARCHAR(255),
    CHECK (cleared_timestamp IS NULL OR cleared_timestamp >= timestamp)
);

COMMENT ON TABLE iot.Alert IS 'Alertes opérationnelles (surcharge, défaut, échauffement)';
COMMENT ON COLUMN iot.Alert.label_fr IS 'Libellé en français';
COMMENT ON COLUMN iot.Alert.label_ar IS 'Libellé en arabe';
COMMENT ON COLUMN iot.Alert.label_default IS 'Libellé par défaut (anglais)';

-- ============================================================
-- 12. TABLE DE CORRESPONDANCE DES CODES GÉOGRAPHIQUES
-- ============================================================

CREATE TABLE public.CodeGeoMapping (
    code_geo            VARCHAR(10) PRIMARY KEY,
    longitude_deg       DOUBLE PRECISION NOT NULL,
    latitude_deg        DOUBLE PRECISION NOT NULL,
    hemispere           VARCHAR(1) CHECK (hemispere IN ('E', 'O')),  -- Est ou Ouest
    x_coord_abs         INTEGER,  -- Valeur absolue 1000 * longitude
    y_coord_abs         INTEGER,  -- Valeur absolue 1000 * latitude
    localite_fr         VARCHAR(255),
    localite_ar         VARCHAR(255),
    localite_default    VARCHAR(255),
    code_adm            VARCHAR(50),
    localite_type       VARCHAR(30) CHECK (localite_type IN ('VILLE', 'COMMUNE', 'VILLAGE', 'HAMEAU', 'CAMPEMENT')),
    created_date        TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE public.CodeGeoMapping IS 'Correspondance des codes géographiques avec les coordonnées';

-- Fonction de génération du code géographique
CREATE OR REPLACE FUNCTION electrique.generate_code_geo(
    lon DOUBLE PRECISION,
    lat DOUBLE PRECISION
)
RETURNS VARCHAR(10) AS $$
DECLARE
    hemispere CHAR(1);
    x_abs INTEGER;
    y_abs INTEGER;
BEGIN
    -- Déterminer l'hémisphère (0 pour Est, 9 pour Ouest)
    IF lon >= 0 THEN
        hemispere := '0';
    ELSE
        hemispere := '9';
    END IF;
    
    -- Calculer les valeurs absolues (1000 * coordonnée en degrés décimaux)
    x_abs := ABS(FLOOR(lon * 1000));
    y_abs := ABS(FLOOR(lat * 1000));
    
    -- Formater le code (SXXXXYYYY)
    RETURN hemispere || LPAD(x_abs::TEXT, 4, '0') || LPAD(y_abs::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION electrique.generate_code_geo IS 'Génère un code géographique au format SXXXXYYYY à partir des coordonnées longitude/latitude';

-- ============================================================
-- 13. INDEX ET CONTRAINTES COMPLÉMENTAIRES
-- ============================================================

-- Index spatiaux
CREATE INDEX idx_structureline_shape ON electrique.StructureLine USING GIST (shape);
CREATE INDEX idx_structurejunction_shape ON electrique.StructureJunction USING GIST (shape);
CREATE INDEX idx_structureboundary_shape ON electrique.StructureBoundary USING GIST (shape);
CREATE INDEX idx_electricline_shape ON electrique.ElectricLine USING GIST (shape);
CREATE INDEX idx_electricdevice_shape ON electrique.ElectricDevice USING GIST (shape);
CREATE INDEX idx_connectionrequest_location ON metier.ConnectionRequest USING GIST (requested_location);

-- Index sur les codes géographiques
CREATE INDEX idx_structureline_code_geo ON electrique.StructureLine (code_geo);
CREATE INDEX idx_structurejunction_code_geo ON electrique.StructureJunction (code_geo);
CREATE INDEX idx_electricline_code_geo ON electrique.ElectricLine (code_geo);
CREATE INDEX idx_electricdevice_code_geo ON electrique.ElectricDevice (code_geo);
CREATE INDEX idx_customer_code_geo ON metier.CustomerAccount (code_geo);

-- Index sur les labels pour recherche multilingue
CREATE INDEX idx_structureline_label_fr ON electrique.StructureLine (label_fr);
CREATE INDEX idx_structureline_label_ar ON electrique.StructureLine (label_ar);
CREATE INDEX idx_electricline_label_fr ON electrique.ElectricLine (label_fr);
CREATE INDEX idx_electricline_label_ar ON electrique.ElectricLine (label_ar);
CREATE INDEX idx_electricdevice_label_fr ON electrique.ElectricDevice (label_fr);
CREATE INDEX idx_electricdevice_label_ar ON electrique.ElectricDevice (label_ar);

-- Index sur les types de localité
CREATE INDEX idx_electricline_localite_type ON electrique.ElectricLine (localite_type);
CREATE INDEX idx_electricdevice_localite_type ON electrique.ElectricDevice (localite_type);
CREATE INDEX idx_customer_localite_type ON metier.CustomerAccount (localite_type);

-- Index fonctionnels
CREATE INDEX idx_outagelog_starttime ON metier.OutageLog (outage_starttime);
CREATE INDEX idx_outagelog_affected ON metier.OutageLog (affected_feature_globalid);
CREATE INDEX idx_intervention_affected ON metier.InterventionLog (affected_feature_globalid, actual_start_date);
CREATE INDEX idx_connectionrequest_status ON metier.ConnectionRequest (status, request_date);
CREATE INDEX idx_telemetry_timestamp ON iot.TelemetryReading (timestamp);
CREATE INDEX idx_telemetry_asset ON iot.TelemetryReading (asset_globalid, timestamp);

-- Index pour les clés étrangères polymorphiques
CREATE INDEX idx_outage_globalid_class ON metier.OutageLog (affected_feature_class, affected_feature_globalid);
CREATE INDEX idx_intervention_globalid_class ON metier.InterventionLog (affected_feature_class, affected_feature_globalid);

-- ============================================================
-- 14. VUES UTILES AVEC LABELS MULTILINGUES
-- ============================================================

-- Vue pour obtenir le libellé selon la langue préférée
CREATE OR REPLACE VIEW electrique.v_LocalizedLabel AS
SELECT 
    'ElectricLine' AS feature_type,
    globalid,
    COALESCE(NULLIF(label_fr, ''), NULLIF(label_default, ''), globalid::TEXT) AS label_fr,
    COALESCE(NULLIF(label_ar, ''), NULLIF(label_default, ''), globalid::TEXT) AS label_ar,
    COALESCE(NULLIF(label_default, ''), globalid::TEXT) AS label_default,
    code_geo,
    localite_type,
    code_adm
FROM electrique.ElectricLine
UNION ALL
SELECT 
    'ElectricDevice',
    globalid,
    COALESCE(NULLIF(label_fr, ''), NULLIF(label_default, ''), globalid::TEXT),
    COALESCE(NULLIF(label_ar, ''), NULLIF(label_default, ''), globalid::TEXT),
    COALESCE(NULLIF(label_default, ''), globalid::TEXT),
    code_geo,
    localite_type,
    code_adm
FROM electrique.ElectricDevice
UNION ALL
SELECT 
    'StructureLine',
    globalid,
    COALESCE(NULLIF(label_fr, ''), NULLIF(label_default, ''), globalid::TEXT),
    COALESCE(NULLIF(label_ar, ''), NULLIF(label_default, ''), globalid::TEXT),
    COALESCE(NULLIF(label_default, ''), globalid::TEXT),
    code_geo,
    NULL AS localite_type,
    NULL AS code_adm
FROM electrique.StructureLine
UNION ALL
SELECT 
    'StructureJunction',
    globalid,
    COALESCE(NULLIF(label_fr, ''), NULLIF(label_default, ''), globalid::TEXT),
    COALESCE(NULLIF(label_ar, ''), NULLIF(label_default, ''), globalid::TEXT),
    COALESCE(NULLIF(label_default, ''), globalid::TEXT),
    code_geo,
    NULL,
    NULL
FROM electrique.StructureJunction;

COMMENT ON VIEW electrique.v_LocalizedLabel IS 'Vue multilingue pour obtenir les libellés localisés';

-- ============================================================
-- 15. TRIGGERS POUR GÉNÉRATION AUTOMATIQUE DU CODE_GEO
-- ============================================================

-- Fonction pour générer automatiquement le code_geo à partir de la géométrie
CREATE OR REPLACE FUNCTION electrique.auto_generate_code_geo()
RETURNS TRIGGER AS $$
DECLARE
    lon DOUBLE PRECISION;
    lat DOUBLE PRECISION;
BEGIN
    -- Vérifier si la géométrie existe et si le code_geo est NULL
    IF NEW.shape IS NOT NULL AND (NEW.code_geo IS NULL OR NEW.code_geo = '') THEN
        -- Extraire la longitude et latitude selon le type de géométrie
        IF TG_TABLE_NAME = 'ElectricLine' OR TG_TABLE_NAME = 'StructureLine' THEN
            -- Pour les lignes, prendre le point de départ
            lon := ST_X(ST_StartPoint(NEW.shape));
            lat := ST_Y(ST_StartPoint(NEW.shape));
        ELSE
            -- Pour les points
            lon := ST_X(NEW.shape);
            lat := ST_Y(NEW.shape);
        END IF;
        
        -- Générer le code géographique
        NEW.code_geo := electrique.generate_code_geo(lon, lat);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour génération automatique du code_geo
CREATE TRIGGER trg_electricline_code_geo
    BEFORE INSERT OR UPDATE ON electrique.ElectricLine
    FOR EACH ROW
    EXECUTE FUNCTION electrique.auto_generate_code_geo();

CREATE TRIGGER trg_electricdevice_code_geo
    BEFORE INSERT OR UPDATE ON electrique.ElectricDevice
    FOR EACH ROW
    EXECUTE FUNCTION electrique.auto_generate_code_geo();

CREATE TRIGGER trg_structureline_code_geo
    BEFORE INSERT OR UPDATE ON electrique.StructureLine
    FOR EACH ROW
    EXECUTE FUNCTION electrique.auto_generate_code_geo();

CREATE TRIGGER trg_structurejunction_code_geo
    BEFORE INSERT OR UPDATE ON electrique.StructureJunction
    FOR EACH ROW
    EXECUTE FUNCTION electrique.auto_generate_code_geo();

-- ============================================================
-- FIN DU SCRIPT 04-electric-network.sql
-- ============================================================