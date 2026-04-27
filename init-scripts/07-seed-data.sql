-- ============================================================
-- 07-seed-data.sql
-- Données de test pour le réseau électrique (optionnel)
-- ============================================================

SET search_path TO electrique, metier, iot, authentification, public;

-- ============================================================
-- INSERTION DE CATALOGUE D'ASSETS
-- ============================================================

INSERT INTO electrique.AssetTypeCatalog (asset_type_code, domain, asset_group, asset_type, tier, description) VALUES
    ('THT_400', 'Electric', 'ThighVoltageTransmission', 'ThighTransmissionThreePhase', 1, 'Ligne THT 400kV triphasée'),
    ('HT_225', 'Electric', 'ThighVoltageTransmission', 'ThighTransmissionThreePhase', 1, 'Ligne THT 225kV triphasée'),
    ('HT_63', 'Electric', 'HighVoltageDistribution', 'HVDistribution_63kV', 2, 'Ligne HT 63kV'),
    ('MT_20', 'Electric', 'HighVoltageDistribution', 'HVDistribution_20kV', 2, 'Ligne MT 20kV'),
    ('BT_400', 'Electric', 'MediumVoltageLocal', 'MVLocal_400V_3Phase', 3, 'Ligne BT 400V triphasée'),
    ('BT_230', 'Electric', 'MediumVoltageLocal', 'MVLocal_230V_SinglePhase', 3, 'Ligne BT 230V monophasée'),
    ('SERVICE_AERIAL', 'Electric', 'ServiceLine', 'ServiceLine_Aerial', 4, 'Raccordement aérien client'),
    ('SERVICE_UG', 'Electric', 'ServiceLine', 'ServiceLine_Underground', 4, 'Raccordement souterrain client'),
    ('TRANSFO_400_225', 'Electric', 'Transformer', 'PowerTransformer_400kV', 1, 'Transformateur 400/225kV'),
    ('TRANSFO_20_04', 'Electric', 'Transformer', 'DistributionTransformer_20kV', 2, 'Transformateur 20/0.4kV'),
    ('TRANSFO_POLE', 'Electric', 'Transformer', 'ServiceTransformer_Pole', 3, 'Transformateur sur poteau'),
    ('BREAKER_SF6', 'Electric', 'Breaker', 'Breaker_SF6_400kV', 1, 'Disjoncteur SF6 THT'),
    ('BREAKER_OIL', 'Electric', 'Breaker', 'Breaker_Oil_20kV', 2, 'Disjoncteur huile HT'),
    ('RECLOSER', 'Electric', 'Recloser', 'Recloser_Motorized', 2, 'Récluseur motorisé'),
    ('SWITCH_ISOLATOR', 'Electric', 'Switch', 'Switch_Isolator', 2, 'Sectionneur isolateur'),
    ('METER_SINGLE', 'Electric', 'Meter', 'Meter_SinglePhase', 4, 'Compteur monophasé'),
    ('METER_THREE', 'Electric', 'Meter', 'Meter_ThreePhase', 4, 'Compteur triphasé'),
    ('POLE_WOOD', 'Structure', 'Pole', 'Wood_Pole_12m', NULL, 'Poteau bois 12m'),
    ('POLE_CONCRETE', 'Structure', 'Pole', 'Concrete_Pole_9m', NULL, 'Poteau béton 9m'),
    ('MANHOLE_CI', 'Structure', 'Manhole', 'CastIron_Manhole_1x1', NULL, 'Regard fonte 1x1m'),
    ('DUCT_PVC', 'Structure', 'Conduit', 'PVC_150mm', NULL, 'Fourreau PVC 150mm');

-- ============================================================
-- INSERTION D'ÉQUIPEMENTS DE TEST (avec géométrie)
-- ============================================================

-- Poteaux (StructureJunction)
INSERT INTO electrique.StructureJunction (globalid, assetgroup, assettype, operationalstatus, lifecycle, validfrom, shape, responsibiliteam)
VALUES 
    (gen_random_uuid(), 'Pole', 'Concrete_Pole_9m', 'In Service', 'Existing', '2020-01-01', 
     ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326), 'Team North'),
    (gen_random_uuid(), 'Pole', 'Wood_Pole_12m', 'In Service', 'Existing', '2020-01-01', 
     ST_SetSRID(ST_MakePoint(2.3572, 48.8616), 4326), 'Team North'),
    (gen_random_uuid(), 'Pole', 'Concrete_Pole_9m', 'In Service', 'Existing', '2020-01-01', 
     ST_SetSRID(ST_MakePoint(2.3622, 48.8666), 4326), 'Team North');

-- Lignes électriques
INSERT INTO electrique.ElectricLine (globalid, assetgroup, assettype, tier, operationalstatus, lifecycle, validfrom, 
                                      installation_method, rated_voltage_kv, length_m, shape, responsibiliteam)
VALUES 
    (gen_random_uuid(), 'HighVoltageDistribution', 'HVDistribution_20kV', 2, 'In Service', 'Existing', '2020-01-01',
     'Overhead', 20.0, 1250.5, 
     ST_SetSRID(ST_MakeLine(ST_MakePoint(2.3522, 48.8566), ST_MakePoint(2.3572, 48.8616), ST_MakePoint(2.3622, 48.8666)), 4326),
     'Team North');

-- Transformateur
INSERT INTO electrique.ElectricDevice (globalid, assetgroup, assettype, tier, operationalstatus, lifecycle, validfrom,
                                         capacity_kva, manufacturer, installation_method, shape, responsibiliteam)
VALUES 
    (gen_random_uuid(), 'Transformer', 'DistributionTransformer_20kV', 2, 'In Service', 'Existing', '2020-01-01',
     630.0, 'Schneider Electric', 'PadMounted',
     ST_SetSRID(ST_MakePoint(2.3572, 48.8616), 4326), 'Team North');

-- Client
INSERT INTO metier.CustomerAccount (customer_id, customer_name, service_point_globalid, voltage_class, billing_status, 
                                      actual_consumption_kwh, estimated_annual_kwh, contact_email)
VALUES 
    (gen_random_uuid(), 'Client Test SARL', (SELECT globalid FROM electrique.ElectricDevice WHERE assettype = 'DistributionTransformer_20kV' LIMIT 1),
     'SME_400V', 'Active', 12500.0, 52000.0, 'contact@client-test.com');

-- ============================================================
-- INSERTION D'UNE PANNE DE TEST
-- ============================================================
INSERT INTO metier.OutageLog (outage_id, outage_starttime, affected_feature_class, affected_feature_globalid, 
                               root_cause_category, root_cause_detail, impacted_customer_count, impacted_demand_mw)
VALUES 
    (gen_random_uuid(), NOW() - INTERVAL '2 hours', 'ElectricDevice', 
     (SELECT globalid FROM electrique.ElectricDevice WHERE assettype = 'DistributionTransformer_20kV' LIMIT 1),
     'Equipment_Failure', 'Surcharge transformateur - déclenchement thermique', 45, 0.28);

-- ============================================================
-- INSERTION DE TÉLÉMÉTRIE DE TEST
-- ============================================================
INSERT INTO iot.TelemetryReading (reading_id, asset_globalid, timestamp, parameter, value, unit, quality)
SELECT 
    gen_random_uuid(),
    (SELECT globalid FROM electrique.ElectricDevice WHERE assettype = 'DistributionTransformer_20kV' LIMIT 1),
    generate_series(NOW() - INTERVAL '1 day', NOW(), INTERVAL '1 hour'),
    'Current_A',
    350 + (random() * 100),
    'A',
    'Good'
FROM generate_series(1, 24);