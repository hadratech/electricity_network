-- ============================================================
-- 05-indexes-constraints.sql
-- Index et contraintes supplémentaires
-- ============================================================

SET search_path TO electrique, metier, iot, public;

-- ============================================================
-- INDEX SPATIAUX
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_structureline_shape ON electrique.StructureLine USING GIST (shape);
CREATE INDEX IF NOT EXISTS idx_structurejunction_shape ON electrique.StructureJunction USING GIST (shape);
CREATE INDEX IF NOT EXISTS idx_structureboundary_shape ON electrique.StructureBoundary USING GIST (shape);
CREATE INDEX IF NOT EXISTS idx_electricline_shape ON electrique.ElectricLine USING GIST (shape);
CREATE INDEX IF NOT EXISTS idx_electricdevice_shape ON electrique.ElectricDevice USING GIST (shape);
CREATE INDEX IF NOT EXISTS idx_connectionrequest_location ON metier.ConnectionRequest USING GIST (requested_location);

-- ============================================================
-- INDEX FONCTIONNELS
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_outagelog_starttime ON metier.OutageLog (outage_starttime);
CREATE INDEX IF NOT EXISTS idx_outagelog_affected ON metier.OutageLog (affected_feature_globalid);
CREATE INDEX IF NOT EXISTS idx_intervention_affected ON metier.InterventionLog (affected_feature_globalid, actual_start_date);
CREATE INDEX IF NOT EXISTS idx_connectionrequest_status ON metier.ConnectionRequest (status, request_date);

-- Index pour clés étrangères polymorphiques
CREATE INDEX IF NOT EXISTS idx_outage_globalid_class ON metier.OutageLog (affected_feature_class, affected_feature_globalid);
CREATE INDEX IF NOT EXISTS idx_intervention_globalid_class ON metier.InterventionLog (affected_feature_class, affected_feature_globalid);

-- ============================================================
-- INDEX POUR PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_electricline_operational ON electrique.ElectricLine (operationalstatus, tier) WHERE validto IS NULL;
CREATE INDEX IF NOT EXISTS idx_electricdevice_operational ON electrique.ElectricDevice (operationalstatus, assetgroup) WHERE validto IS NULL;
CREATE INDEX IF NOT EXISTS idx_customer_billing ON metier.CustomerAccount (billing_status, voltage_class);

-- ============================================================
-- CONTRAINTES D'INTÉGRITÉ
-- ============================================================

-- Foreign key vers authentification.utilisateurs (si nécessaire)
-- ALTER TABLE electrique.StructureLine ADD CONSTRAINT fk_structureline_created_by 
--     FOREIGN KEY (created_by) REFERENCES authentification.utilisateurs(user_uuid);
-- ALTER TABLE electrique.ElectricLine ADD CONSTRAINT fk_electricline_created_by 
--     FOREIGN KEY (created_by) REFERENCES authentification.utilisateurs(user_uuid);
-- ALTER TABLE metier.InterventionLog ADD CONSTRAINT fk_intervention_technician 
--     FOREIGN KEY (technician_id) REFERENCES authentification.utilisateurs(user_uuid);
-- ALTER TABLE iot.Alert ADD CONSTRAINT fk_alert_acknowledged_by 
--     FOREIGN KEY (acknowledged_by) REFERENCES authentification.utilisateurs(user_uuid);

-- ============================================================
-- COMMENTAIRES SUR LE PARTITIONNEMENT
-- ============================================================
-- Pour les tables volumineuses (OutageLog, TelemetryReading), 
-- il est recommandé d'utiliser le partitionnement par mois.
-- Exemple pour TelemetryReading (à adapter selon vos besoins) :
/*
CREATE TABLE iot.TelemetryReading_2025_01 PARTITION OF iot.TelemetryReading
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE iot.TelemetryReading_2025_02 PARTITION OF iot.TelemetryReading
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
*/