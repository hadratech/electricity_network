-- ============================================================
-- 01-init-extensions.sql
-- Initialisation des extensions PostgreSQL
-- ============================================================

-- UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- PostGIS pour les données spatiales
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_raster;

-- Utilitaires
CREATE EXTENSION IF NOT EXISTS "fuzzystrmatch";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "hstore";
CREATE EXTENSION IF NOT EXISTS "citext";

-- Statistiques
CREATE EXTENSION IF NOT EXISTS "tablefunc";

-- Vérification
DO $$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Extensions activées avec succès';
    RAISE NOTICE 'PostGIS version: %', (SELECT PostGIS_Version());
    RAISE NOTICE '==========================================';
END $$;