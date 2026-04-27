-- ============================================================
-- 02-schemas-creation.sql
-- Création des schémas
-- ============================================================

-- Schéma pour l'authentification
CREATE SCHEMA IF NOT EXISTS authentification;
COMMENT ON SCHEMA authentification IS 'Gestion des utilisateurs, rôles et sessions';

-- Schéma pour le réseau électrique
CREATE SCHEMA IF NOT EXISTS electrique;
COMMENT ON SCHEMA electrique IS 'Réseau électrique : lignes, équipements, structure';

-- Schéma pour les données métier
CREATE SCHEMA IF NOT EXISTS metier;
COMMENT ON SCHEMA metier IS 'Données métier : pannes, interventions, clients';

-- Schéma pour l'IoT et la télémétrie
CREATE SCHEMA IF NOT EXISTS iot;
COMMENT ON SCHEMA iot IS 'Données IoT : télémétrie, alertes';

-- Définition des propriétaires (à adapter selon vos besoins)
-- ALTER SCHEMA authentification OWNER TO sif_user;
-- ALTER SCHEMA electrique OWNER TO sif_user;
-- ALTER SCHEMA metier OWNER TO sif_user;
-- ALTER SCHEMA iot OWNER TO sif_user;

-- Permissions de base
GRANT USAGE ON SCHEMA authentification TO public;
GRANT USAGE ON SCHEMA electrique TO public;
GRANT USAGE ON SCHEMA metier TO public;
GRANT USAGE ON SCHEMA iot TO public;