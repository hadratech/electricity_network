-- ============================================================
-- 03-authentication.sql
-- Tables d'authentification dans le schéma authentification
-- Basé sur le dump fourni, adapté pour PostgreSQL 15
-- ============================================================

SET search_path TO authentification, public;

-- ============================================================
-- TABLE: utilisateurs
-- ============================================================
CREATE TABLE utilisateurs (
    user_uuid UUID DEFAULT gen_random_uuid() NOT NULL,
    nni VARCHAR(20) NOT NULL,
    nom VARCHAR(100) NOT NULL,
    prenom VARCHAR(100),
    type_utilisateur VARCHAR(50) NOT NULL,
    email VARCHAR(255),
    telephone VARCHAR(20),
    adresse_postale TEXT,
    date_creation TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    date_maj TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    actif BOOLEAN DEFAULT true,
    -- Champs supplémentaires pour le réseau électrique
    service_id UUID,  -- Pour lier à une équipe de maintenance
    zone_intervention VARCHAR(100),  -- Zone géographique d'intervention
    CONSTRAINT utilisateurs_type_check CHECK (
        type_utilisateur IN ('CITOYEN', 'NOTAIRE', 'AGENT_DGDE', 'CONSERVATEUR', 'ADMINISTRATEUR', 'TECHNICIEN', 'INGENIEUR')
    )
);

COMMENT ON TABLE utilisateurs IS 'Utilisateurs du système (authentification)';
COMMENT ON COLUMN utilisateurs.nni IS 'Numéro National d''Identification (unique)';
COMMENT ON COLUMN utilisateurs.type_utilisateur IS 'Type d''utilisateur définissant ses droits';

-- ============================================================
-- TABLE: roles
-- ============================================================
CREATE TABLE roles (
    role_uuid UUID DEFAULT gen_random_uuid() NOT NULL,
    code_role VARCHAR(50) NOT NULL,
    libelle VARCHAR(100) NOT NULL,
    description TEXT,
    permissions JSONB DEFAULT '{}'::jsonb NOT NULL,
    date_creation TIMESTAMP WITHOUT TIME ZONE DEFAULT now()
);

COMMENT ON TABLE roles IS 'Rôles et permissions associées';

-- ============================================================
-- TABLE: user_roles
-- ============================================================
CREATE TABLE user_roles (
    user_role_uuid UUID DEFAULT gen_random_uuid() NOT NULL,
    user_uuid UUID NOT NULL,
    role_uuid UUID NOT NULL,
    date_attribution TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    date_expiration TIMESTAMP WITHOUT TIME ZONE,
    actif BOOLEAN DEFAULT true
);

COMMENT ON TABLE user_roles IS 'Association utilisateurs - rôles';

-- ============================================================
-- TABLE: sessions
-- ============================================================
CREATE TABLE sessions (
    session_uuid UUID DEFAULT gen_random_uuid() NOT NULL,
    user_uuid UUID NOT NULL,
    token_acces TEXT NOT NULL,
    token_rafraichissement TEXT,
    date_creation TIMESTAMP WITHOUT TIME ZONE DEFAULT now(),
    date_expiration TIMESTAMP WITHOUT TIME ZONE NOT NULL,
    adresse_ip INET,
    user_agent TEXT,
    active BOOLEAN DEFAULT true
);

COMMENT ON TABLE sessions IS 'Sessions actives des utilisateurs';

-- ============================================================
-- CONTRAINTES PK
-- ============================================================
ALTER TABLE utilisateurs ADD CONSTRAINT utilisateurs_pkey PRIMARY KEY (user_uuid);
ALTER TABLE roles ADD CONSTRAINT roles_pkey PRIMARY KEY (role_uuid);
ALTER TABLE user_roles ADD CONSTRAINT user_roles_pkey PRIMARY KEY (user_role_uuid);
ALTER TABLE sessions ADD CONSTRAINT sessions_pkey PRIMARY KEY (session_uuid);

-- ============================================================
-- CONTRAINTES UNIQUES
-- ============================================================
ALTER TABLE utilisateurs ADD CONSTRAINT uk_nni_unique UNIQUE (nni);
ALTER TABLE roles ADD CONSTRAINT roles_code_role_key UNIQUE (code_role);
ALTER TABLE user_roles ADD CONSTRAINT uk_user_role_unique UNIQUE (user_uuid, role_uuid);

-- ============================================================
-- INDEX
-- ============================================================
CREATE INDEX idx_utilisateurs_nni ON utilisateurs (nni);
CREATE INDEX idx_utilisateurs_type ON utilisateurs (type_utilisateur);
CREATE INDEX idx_utilisateurs_actif ON utilisateurs (actif);
CREATE INDEX idx_sessions_token ON sessions (token_acces);
CREATE INDEX idx_sessions_user ON sessions (user_uuid);
CREATE INDEX idx_sessions_active ON sessions (active);
CREATE INDEX idx_user_roles_user ON user_roles (user_uuid);
CREATE INDEX idx_user_roles_role ON user_roles (role_uuid);

-- ============================================================
-- FOREIGN KEYS
-- ============================================================
ALTER TABLE user_roles ADD CONSTRAINT user_roles_user_fkey 
    FOREIGN KEY (user_uuid) REFERENCES utilisateurs(user_uuid) ON DELETE CASCADE;
ALTER TABLE user_roles ADD CONSTRAINT user_roles_role_fkey 
    FOREIGN KEY (role_uuid) REFERENCES roles(role_uuid) ON DELETE CASCADE;
ALTER TABLE sessions ADD CONSTRAINT sessions_user_fkey 
    FOREIGN KEY (user_uuid) REFERENCES utilisateurs(user_uuid) ON DELETE CASCADE;

-- ============================================================
-- INSERTION DES RÔLES DE BASE
-- ============================================================
INSERT INTO roles (code_role, libelle, description, permissions) VALUES
    ('CITOYEN', 'Citoyen', 'Utilisateur standard', 
     '{"demander": ["verification", "plans"], "consulter": ["profil", "documents"]}'),
    ('NOTAIRE', 'Notaire', 'Professionnel habilité aux actes juridiques', 
     '{"deposer": ["actes"], "consulter": ["cadastre", "propriete"]}'),
    ('AGENT_DGDE', 'Agent DGDE', 'Agent administratif de la DGDE', 
     '{"generer": ["documents"], "valider": ["dossiers"], "consulter": ["tous"]}'),
    ('CONSERVATEUR', 'Conservateur', 'Responsable de la conservation foncière', 
     '{"valider": ["titres"], "archiver": ["documents"], "consulter": ["tous"]}'),
    ('ADMIN_SYSTEME', 'Administrateur Système', 'Administrateur technique', 
     '{"modifier": ["tous"], "consulter": ["tous"], "administrer": ["utilisateurs", "systeme"]}'),
    ('TECHNICIEN', 'Technicien Réseau', 'Technicien de maintenance électrique', 
     '{"intervenir": ["pannes", "maintenance"], "consulter": ["reseau", "equipements"]}'),
    ('INGENIEUR', 'Ingénieur Réseau', 'Ingénieur planification réseau', 
     '{"planifier": ["travaux"], "modifier": ["reseau"], "consulter": ["analyses"]}');

-- ============================================================
-- INSERTION D'UN UTILISATEUR ADMIN PAR DÉFAUT
-- ============================================================
-- Mot de passe à gérer via une fonction de hashage (bcrypt) dans l'application
-- Ici on insère un utilisateur admin de base
INSERT INTO utilisateurs (user_uuid, nni, nom, prenom, type_utilisateur, email, actif) 
VALUES (gen_random_uuid(), 'ADMIN001', 'ADMIN', 'System', 'ADMINISTRATEUR', 'admin@electricite.ma', true)
ON CONFLICT (nni) DO NOTHING;

-- Assigner le rôle ADMIN_SYSTEME à l'admin (à faire après récupération de l'UUID)
DO $$
DECLARE
    admin_uuid UUID;
    admin_role_uuid UUID;
BEGIN
    SELECT user_uuid INTO admin_uuid FROM utilisateurs WHERE nni = 'ADMIN001' LIMIT 1;
    SELECT role_uuid INTO admin_role_uuid FROM roles WHERE code_role = 'ADMIN_SYSTEME' LIMIT 1;
    
    IF admin_uuid IS NOT NULL AND admin_role_uuid IS NOT NULL THEN
        INSERT INTO user_roles (user_uuid, role_uuid) 
        VALUES (admin_uuid, admin_role_uuid)
        ON CONFLICT (user_uuid, role_uuid) DO NOTHING;
    END IF;
END $$;

-- ============================================================
-- GRANTS (Permissions)
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_anon') THEN
        CREATE ROLE web_anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'web_user') THEN
        CREATE ROLE web_user NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'api_user') THEN
        CREATE ROLE api_user NOLOGIN;
    END IF;
END;
$$;

-- Web anonymous (read-only)
GRANT USAGE ON SCHEMA authentification TO web_anon;
GRANT SELECT ON utilisateurs TO web_anon;
GRANT SELECT ON roles TO web_anon;
GRANT SELECT ON user_roles TO web_anon;

-- Web user (read/write on some tables)
GRANT USAGE ON SCHEMA authentification TO web_user;
GRANT SELECT, INSERT, UPDATE ON utilisateurs TO web_user;
GRANT SELECT ON roles TO web_user;
GRANT SELECT, INSERT, UPDATE ON user_roles TO web_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON sessions TO web_user;

-- API user (full access to authentication)
GRANT USAGE ON SCHEMA authentification TO api_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA authentification TO api_user;