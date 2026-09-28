-- ============================================================
-- 08-regional-access.sql
-- Référentiel des wilayas et indicateurs d'accès à l'électricité
-- ============================================================

CREATE TABLE IF NOT EXISTS metier.AdministrativeArea (
    area_code       VARCHAR(10) PRIMARY KEY,
    country_code    CHAR(2) NOT NULL DEFAULT 'MR',
    admin_level     SMALLINT NOT NULL DEFAULT 1 CHECK (admin_level = 1),
    name_fr         VARCHAR(100) NOT NULL,
    boundary_id     VARCHAR(10) NOT NULL UNIQUE,
    shape           GEOMETRY(Polygon, 4326),
    created_date    TIMESTAMP NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE metier.AdministrativeArea IS 'Référentiel des unités administratives utilisé pour les statistiques territoriales';

INSERT INTO metier.AdministrativeArea (area_code, name_fr, boundary_id) VALUES
    ('MR01', 'Hodh ech Chargui', 'MR01'),
    ('MR02', 'Hodh el Gharbi', 'MR02'),
    ('MR03', 'Assaba', 'MR03'),
    ('MR04', 'Gorgol', 'MR04'),
    ('MR05', 'Brakna', 'MR05'),
    ('MR06', 'Trarza', 'MR06'),
    ('MR07', 'Adrar', 'MR07'),
    ('MR08', 'Dakhlet Nouadhibou', 'MR08'),
    ('MR09', 'Tagant', 'MR09'),
    ('MR10', 'Guidimaka', 'MR10'),
    ('MR11', 'Tiris Zemmour', 'MR11'),
    ('MR12', 'Inchiri', 'MR12'),
    ('MR13', 'Nouakchott-Ouest', 'MR13'),
    ('MR14', 'Nouakchott-Nord', 'MR14'),
    ('MR15', 'Nouakchott-Sud', 'MR15')
ON CONFLICT (area_code) DO UPDATE
SET name_fr = EXCLUDED.name_fr,
    boundary_id = EXCLUDED.boundary_id;

CREATE TABLE IF NOT EXISTS metier.WilayaAccessSnapshot (
    snapshot_id                         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_object                           VARCHAR(50) NOT NULL,
    area_code                           VARCHAR(10) NOT NULL REFERENCES metier.AdministrativeArea(area_code),
    reference_year                      SMALLINT NOT NULL CHECK (reference_year BETWEEN 1900 AND 2200),
    population                          INTEGER NOT NULL CHECK (population >= 0),
    subscribers                         INTEGER NOT NULL CHECK (subscribers >= 0),
    access_rate_pct                     NUMERIC(5,2) NOT NULL CHECK (access_rate_pct BETWEEN 0 AND 100),
    electrified_localities              INTEGER CHECK (electrified_localities >= 0),
    total_localities                    INTEGER NOT NULL CHECK (total_localities >= 0),
    localities_population_over_300      INTEGER CHECK (localities_population_over_300 >= 0),
    localities_population_over_500      INTEGER CHECK (localities_population_over_500 >= 0),
    localities_population_over_1000     INTEGER CHECK (localities_population_over_1000 >= 0),
    source                              TEXT NOT NULL,
    source_page                         SMALLINT NOT NULL CHECK (source_page > 0),
    extraction_method                   TEXT NOT NULL,
    validation_status                   TEXT NOT NULL,
    date_saisie                         TIMESTAMPTZ NOT NULL,
    notes                               TEXT,
    created_date                        TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_wilaya_access_id_object UNIQUE (id_object),
    CONSTRAINT uq_wilaya_access_area_year_source UNIQUE (area_code, reference_year, source),
    CHECK (electrified_localities IS NULL OR electrified_localities <= total_localities),
    CHECK (localities_population_over_300 IS NULL OR localities_population_over_500 IS NULL OR localities_population_over_300 >= localities_population_over_500),
    CHECK (localities_population_over_500 IS NULL OR localities_population_over_1000 IS NULL OR localities_population_over_500 >= localities_population_over_1000)
);

ALTER TABLE metier.AdministrativeArea
    ADD COLUMN IF NOT EXISTS shape GEOMETRY(Polygon, 4326);
ALTER TABLE metier.WilayaAccessSnapshot
    ADD COLUMN IF NOT EXISTS id_object VARCHAR(50),
    ADD COLUMN IF NOT EXISTS source TEXT,
    ADD COLUMN IF NOT EXISTS date_saisie TIMESTAMPTZ;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'metier'
          AND table_name = 'wilayaaccesssnapshot'
          AND column_name = 'source_document'
    ) THEN
        EXECUTE 'UPDATE metier.WilayaAccessSnapshot SET source = source_document WHERE source IS NULL';
        EXECUTE 'ALTER TABLE metier.WilayaAccessSnapshot ALTER COLUMN source_document DROP NOT NULL';
    END IF;
    UPDATE metier.WilayaAccessSnapshot
    SET source = COALESCE(source, 'legacy'),
        id_object = COALESCE(id_object, area_code || '-' || reference_year || '-' || substr(md5(COALESCE(source, 'legacy')), 1, 8)),
        date_saisie = COALESCE(date_saisie, created_date AT TIME ZONE 'UTC');
END;
$$;

ALTER TABLE metier.WilayaAccessSnapshot
    ALTER COLUMN id_object SET NOT NULL,
    ALTER COLUMN source SET NOT NULL,
    ALTER COLUMN date_saisie SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_wilaya_access_id_object
    ON metier.WilayaAccessSnapshot (id_object);
CREATE UNIQUE INDEX IF NOT EXISTS uq_wilaya_access_area_year_source
    ON metier.WilayaAccessSnapshot (area_code, reference_year, source);

COMMENT ON TABLE metier.WilayaAccessSnapshot IS 'Indicateurs annuels d’accès à l’électricité par wilaya, distincts des actifs du réseau';
COMMENT ON COLUMN metier.WilayaAccessSnapshot.access_rate_pct IS 'Taux reproduit du document source; son dénominateur n''est pas précisé dans les cartes 2024';
COMMENT ON COLUMN metier.WilayaAccessSnapshot.id_object IS 'Identifiant stable de l''observation territoriale (wilaya-année)';
COMMENT ON COLUMN metier.WilayaAccessSnapshot.source IS 'Chemin relatif du document source utilisé pour l''extraction';
COMMENT ON COLUMN metier.WilayaAccessSnapshot.date_saisie IS 'Horodatage UTC de l''extraction/saisie des indicateurs';
COMMENT ON COLUMN metier.WilayaAccessSnapshot.source_page IS 'Page du document source utilisée pour l''extraction';

CREATE TEMP TABLE wilaya_access_import (
    id_object                       VARCHAR(50),
    admin_code                      VARCHAR(10),
    wilaya_name                     VARCHAR(100),
    reference_year                  SMALLINT,
    population                      INTEGER,
    subscribers                     INTEGER,
    access_rate_pct                 NUMERIC(5,2),
    electrified_localities          INTEGER,
    total_localities                INTEGER,
    localities_population_over_300  INTEGER,
    localities_population_over_500  INTEGER,
    localities_population_over_1000 INTEGER,
    geometry_wkt                    TEXT,
    source                          TEXT,
    source_page                     SMALLINT,
    extraction_method               TEXT,
    validation_status               TEXT,
    date_saisie                     TIMESTAMPTZ,
    notes                           TEXT
);

\copy wilaya_access_import FROM '../1411-Donnees_recues/ministere_energies_petrole/03_valide/indicateurs_acces_electricite_wilaya_2024.csv' WITH (FORMAT csv, HEADER true, NULL '')

INSERT INTO metier.AdministrativeArea (area_code, name_fr, boundary_id, shape)
SELECT admin_code, wilaya_name, admin_code, ST_GeomFromText(geometry_wkt, 4326)
FROM wilaya_access_import
WHERE geometry_wkt IS NOT NULL
ON CONFLICT (area_code) DO UPDATE SET
    name_fr = EXCLUDED.name_fr,
    boundary_id = EXCLUDED.boundary_id,
    shape = EXCLUDED.shape;

INSERT INTO metier.WilayaAccessSnapshot (
    id_object, area_code, reference_year, population, subscribers, access_rate_pct,
    electrified_localities, total_localities,
    localities_population_over_300, localities_population_over_500,
    localities_population_over_1000, source, source_page,
    extraction_method, validation_status, date_saisie, notes
)
SELECT
    id_object, admin_code, reference_year, population, subscribers, access_rate_pct,
    electrified_localities, total_localities,
    localities_population_over_300, localities_population_over_500,
    localities_population_over_1000, source, source_page,
    extraction_method, validation_status, date_saisie, notes
FROM wilaya_access_import
WHERE source IS NOT NULL
ON CONFLICT (area_code, reference_year, source) DO UPDATE SET
    id_object = EXCLUDED.id_object,
    population = EXCLUDED.population,
    subscribers = EXCLUDED.subscribers,
    access_rate_pct = EXCLUDED.access_rate_pct,
    electrified_localities = EXCLUDED.electrified_localities,
    total_localities = EXCLUDED.total_localities,
    localities_population_over_300 = EXCLUDED.localities_population_over_300,
    localities_population_over_500 = EXCLUDED.localities_population_over_500,
    localities_population_over_1000 = EXCLUDED.localities_population_over_1000,
    source_page = EXCLUDED.source_page,
    extraction_method = EXCLUDED.extraction_method,
    validation_status = EXCLUDED.validation_status,
    date_saisie = EXCLUDED.date_saisie,
    notes = EXCLUDED.notes;

DROP TABLE wilaya_access_import;