-- ============================================================
-- 06-views-functions.sql
-- Vues utiles et fonctions pour le réseau électrique
-- ============================================================

SET search_path TO electrique, metier, iot, public;

-- ============================================================
-- VUES
-- ============================================================

-- État courant du réseau (équipements actifs)
CREATE VIEW electrique.v_CurrentNetworkState AS
SELECT 'ElectricLine' AS asset_type, globalid, operationalstatus, lifecycle, shape
FROM electrique.ElectricLine
WHERE validto IS NULL AND operationalstatus = 'In Service'
UNION ALL
SELECT 'ElectricDevice', globalid, operationalstatus, lifecycle, shape
FROM electrique.ElectricDevice
WHERE validto IS NULL AND operationalstatus = 'In Service';

COMMENT ON VIEW electrique.v_CurrentNetworkState IS 'État courant du réseau électrique actif';

-- Impact client par panne (7 derniers jours)
CREATE VIEW metier.v_RecentOutageImpact AS
SELECT 
    o.outage_id, 
    o.outage_starttime, 
    o.root_cause_category,
    COUNT(c.customer_id) AS affected_customers,
    SUM(c.estimated_annual_kwh/365) AS estimated_daily_loss_kwh
FROM metier.OutageLog o
LEFT JOIN metier.CustomerAccount c ON c.service_point_globalid = o.affected_feature_globalid
WHERE o.outage_starttime > NOW() - INTERVAL '7 days'
GROUP BY o.outage_id, o.outage_starttime, o.root_cause_category;

COMMENT ON VIEW metier.v_RecentOutageImpact IS 'Impact des pannes des 7 derniers jours';

-- Synthèse des interventions par technicien
CREATE VIEW metier.v_TechnicianInterventions AS
SELECT 
    i.technician_id,
    u.nom AS technician_nom,
    u.prenom AS technician_prenom,
    COUNT(i.intervention_id) AS nb_interventions,
    SUM(i.duration_hours) AS total_hours,
    AVG(i.duration_hours) AS avg_hours,
    SUM(i.total_cost_usd) AS total_cost
FROM metier.InterventionLog i
LEFT JOIN authentification.utilisateurs u ON u.user_uuid = i.technician_id
WHERE i.status = 'Completed'
GROUP BY i.technician_id, u.nom, u.prenom;

-- ============================================================
-- FONCTIONS
-- ============================================================

-- Fonction pour mettre à jour date_maj automatiquement
CREATE OR REPLACE FUNCTION electrique.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_date = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour les tables principales
CREATE TRIGGER update_electricline_moddate 
    BEFORE UPDATE ON electrique.ElectricLine
    FOR EACH ROW EXECUTE FUNCTION electrique.update_modified_column();

CREATE TRIGGER update_electricdevice_moddate 
    BEFORE UPDATE ON electrique.ElectricDevice
    FOR EACH ROW EXECUTE FUNCTION electrique.update_modified_column();

CREATE TRIGGER update_customer_moddate 
    BEFORE UPDATE ON metier.CustomerAccount
    FOR EACH ROW EXECUTE FUNCTION electrique.update_modified_column();

-- Fonction pour trouver le transformateur le plus proche
CREATE OR REPLACE FUNCTION electrique.find_nearest_transformer(
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    max_distance_m DOUBLE PRECISION DEFAULT 1000
)
RETURNS TABLE(
    device_globalid UUID,
    assettype VARCHAR(50),
    capacity_kva DOUBLE PRECISION,
    distance_m DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ed.globalid,
        ed.assettype,
        ed.capacity_kva,
        ST_Distance(ed.shape::GEOGRAPHY, ST_SetSRID(ST_MakePoint(lon, lat), 4326)::GEOGRAPHY) AS distance_m
    FROM electrique.ElectricDevice ed
    WHERE ed.assetgroup = 'Transformer'
      AND ed.operationalstatus = 'In Service'
      AND ed.validto IS NULL
    AND ST_DWithin(ed.shape::GEOGRAPHY, ST_SetSRID(ST_MakePoint(lon, lat), 4326)::GEOGRAPHY, max_distance_m)
    ORDER BY distance_m
    LIMIT 10;
END;
$$ LANGUAGE plpgsql STABLE;

-- Fonction pour créer une alerte de surcharge
CREATE OR REPLACE FUNCTION iot.check_overload_alert()
RETURNS TRIGGER AS $$
DECLARE
    rated_current DOUBLE PRECISION;
    rated_capacity DOUBLE PRECISION;
BEGIN
    -- Récupérer les caractéristiques de l'équipement
    SELECT rated_current_a, capacity_kva 
    INTO rated_current, rated_capacity
    FROM electrique.ElectricDevice 
    WHERE globalid = NEW.asset_globalid;
    
    -- Alerte courant > 90% du nominal
    IF NEW.parameter = 'Current_A' AND rated_current IS NOT NULL AND NEW.value > rated_current * 0.9 THEN
        INSERT INTO iot.Alert (asset_globalid, alert_type, severity, message, timestamp)
        VALUES (
            NEW.asset_globalid, 
            'Overload', 
            CASE WHEN NEW.value > rated_current THEN 'Critical' ELSE 'High' END,
            format('Courant %.1f A dépasse %.0f%% de la capacité nominale (%.1f A)', 
                   NEW.value, (NEW.value / rated_current) * 100, rated_current),
            NEW.timestamp
        );
    END IF;
    
    -- Alerte puissance > 90% du nominal (pour transformateurs)
    IF NEW.parameter = 'Power_kVA' AND rated_capacity IS NOT NULL AND NEW.value > rated_capacity * 0.9 THEN
        INSERT INTO iot.Alert (asset_globalid, alert_type, severity, message, timestamp)
        VALUES (
            NEW.asset_globalid, 
            'Overload', 
            CASE WHEN NEW.value > rated_capacity THEN 'Critical' ELSE 'High' END,
            format('Puissance %.1f kVA dépasse %.0f%% de la capacité nominale (%.1f kVA)', 
                   NEW.value, (NEW.value / rated_capacity) * 100, rated_capacity),
            NEW.timestamp
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour les alertes automatiques
CREATE TRIGGER trg_telemetry_alerts
    AFTER INSERT ON iot.TelemetryReading
    FOR EACH ROW
    EXECUTE FUNCTION iot.check_overload_alert();

-- ============================================================
-- FONCTION D'AUDIT
-- ============================================================

-- Table d'audit (optionnelle)
CREATE TABLE public.audit_log (
    audit_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name      VARCHAR(100),
    operation       VARCHAR(10), -- INSERT, UPDATE, DELETE
    record_globalid UUID,
    old_data        JSONB,
    new_data        JSONB,
    user_uuid       UUID,
    operation_time  TIMESTAMP DEFAULT NOW()
);

-- Fonction d'audit générique
CREATE OR REPLACE FUNCTION public.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.audit_log (table_name, operation, record_globalid, old_data, new_data, user_uuid)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        COALESCE(NEW.globalid, OLD.globalid),
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
        current_setting('app.current_user_uuid', true)::UUID
    );
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;