#!/bin/bash
# ============================================================
# init-db.sh
# Electricity Network GIS Platform - Database Initialization Script
# Version: 2.0.0 (avec support multilingue)
# ============================================================

set -euo pipefail

# ============================================================
# Color codes for output
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# Configuration
# ============================================================
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"
DB_NAME="${DB_NAME:-electricity_network}"
DEFAULT_LANG="${DEFAULT_LANG:-fr}"
FORCE=false
LOAD_SAMPLE_DATA=false
LOAD_GEO_DATA=false

# ============================================================
# Functions
# ============================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

database_exists() {
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -lqt | cut -d \| -f 1 | grep -qw "${DB_NAME}"
}

execute_sql_file() {
    local sql_file=$1
    local description=$2
    
    log_info "Executing: ${description} (${sql_file})"
    
    if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${sql_file}" 2>&1; then
        log_success "Successfully executed: ${description}"
        return 0
    else
        log_error "Failed to execute: ${description}"
        return 1
    fi
}

# ============================================================
# Parse command line arguments
# ============================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --sample-data)
            LOAD_SAMPLE_DATA=true
            shift
            ;;
        --geo-data)
            LOAD_GEO_DATA=true
            shift
            ;;
        --lang)
            DEFAULT_LANG="$2"
            shift 2
            ;;
        --host)
            DB_HOST="$2"
            shift 2
            ;;
        --port)
            DB_PORT="$2"
            shift 2
            ;;
        --user)
            DB_USER="$2"
            shift 2
            ;;
        --password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --dbname)
            DB_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --force               Drop existing database if it exists"
            echo "  --sample-data         Load sample data after schema creation"
            echo "  --geo-data            Load geographic test data"
            echo "  --lang LANG           Default language (fr, ar, en) - default: fr"
            echo "  --host HOST           Database host (default: localhost)"
            echo "  --port PORT           Database port (default: 5432)"
            echo "  --user USER           Database user (default: postgres)"
            echo "  --password PASSWORD   Database password (default: postgres)"
            echo "  --dbname DBNAME       Database name (default: electricity_network)"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# ============================================================
# Main execution
# ============================================================

echo ""
echo "=========================================="
echo "  Electricity Network GIS Platform"
echo "  Database Initialization Script v2.0"
echo "  Multilingual Support (FR/AR/EN)"
echo "=========================================="
echo ""

log_info "Default language: ${DEFAULT_LANG}"

# Test database connection
log_info "Testing database connection to ${DB_HOST}:${DB_PORT} as ${DB_USER}"
if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -c "SELECT 1" &>/dev/null; then
    log_error "Cannot connect to database. Please check your connection parameters."
    exit 1
fi
log_success "Database connection successful"

# Drop existing database if forced
if [ "$FORCE" = true ] && database_exists; then
    log_warning "Dropping existing database: ${DB_NAME}"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -c "DROP DATABASE IF EXISTS ${DB_NAME} WITH (FORCE);"
    log_success "Database dropped"
fi

# Create database if it doesn't exist
if ! database_exists; then
    log_info "Creating database: ${DB_NAME} with UTF-8 encoding"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -c "CREATE DATABASE ${DB_NAME} ENCODING 'UTF8' TEMPLATE=template0;"
    log_success "Database created"
else
    log_info "Database ${DB_NAME} already exists"
fi

# ============================================================
# Execute SQL files in order
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_DIR="${SCRIPT_DIR}/init-scripts"

cd "${SQL_DIR}"

# 1. Extensions
execute_sql_file "01-init-extensions.sql" "PostgreSQL Extensions" || exit 1

# 2. Schemas
execute_sql_file "02-schemas-creation.sql" "Schema Creation" || exit 1

# 3. Authentication
execute_sql_file "03-authentification.sql" "Authentication Tables" || exit 1

# 4. Electric Network (avec labels et code_geo)
execute_sql_file "04-electric-network.sql" "Electric Network Tables (Multilingual)" || exit 1

# 5. Indexes
execute_sql_file "05-indexes-constraints.sql" "Indexes & Constraints" || exit 1

# 6. Views & Functions
execute_sql_file "06-views-functions.sql" "Views & Functions (Multilingual)" || exit 1

# 7. Regional access model and 2024 indicators
execute_sql_file "08-regional-access.sql" "Regional Electricity Access Indicators" || exit 1

# 8. Sample data (optional)
if [ "$LOAD_SAMPLE_DATA" = true ]; then
    execute_sql_file "07-seed-data.sql" "Sample Seed Data" || exit 1
else
    log_info "Skipping sample seed data (use --sample-data to load)"
fi

# 9. Geo data (optional)
if [ "$LOAD_GEO_DATA" = true ]; then
    execute_sql_file "08-geo-data.sql" "Geographic Test Data" || exit 1
else
    log_info "Skipping geographic data (use --geo-data to load)"
fi

# ============================================================
# Post-initialization verification
# ============================================================

log_info "Verifying database initialization..."

# Check if tables exist
TABLE_COUNT=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('electrique', 'metier', 'iot', 'authentification') AND table_type = 'BASE TABLE';" | xargs)

log_info "Created ${TABLE_COUNT} tables across all schemas"

# Check PostGIS
POSTGIS_VERSION=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT PostGIS_Version();" | xargs)
log_info "PostGIS version: ${POSTGIS_VERSION}"

# Check multilingual support
log_info "Checking multilingual configuration..."
PG_LANG=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SHOW lc_messages;" | xargs)
log_info "Database language: ${PG_LANG}"

# ============================================================
# Create default admin user with multilingual labels
# ============================================================
log_info "Creating default admin user..."
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" <<EOF
-- Insert admin user if not exists
INSERT INTO authentification.utilisateurs (user_uuid, nni, nom, prenom, type_utilisateur, email, label_fr, label_ar, label_default, actif) 
VALUES (
    gen_random_uuid(), 
    'ADMIN001', 
    'ADMIN', 
    'System', 
    'ADMINISTRATEUR', 
    'admin@electricite.ma',
    'Administrateur Système',
    'مدير النظام',
    'System Administrator',
    true
) ON CONFLICT (nni) DO NOTHING;

-- Assign admin role
DO \$\$
DECLARE
    admin_uuid UUID;
    admin_role_uuid UUID;
BEGIN
    SELECT user_uuid INTO admin_uuid FROM authentification.utilisateurs WHERE nni = 'ADMIN001' LIMIT 1;
    SELECT role_uuid INTO admin_role_uuid FROM authentification.roles WHERE code_role = 'ADMIN_SYSTEME' LIMIT 1;
    
    IF admin_uuid IS NOT NULL AND admin_role_uuid IS NOT NULL THEN
        INSERT INTO authentification.user_roles (user_uuid, role_uuid) 
        VALUES (admin_uuid, admin_role_uuid)
        ON CONFLICT (user_uuid, role_uuid) DO NOTHING;
    END IF;
END \$\$;
EOF
log_success "Default admin user created"

# ============================================================
# Summary
# ============================================================
echo ""
echo "=========================================="
echo "  Database Initialization Complete!"
echo "=========================================="
echo ""
log_success "Database: ${DB_NAME}"
log_success "Host: ${DB_HOST}:${DB_PORT}"
log_success "User: ${DB_USER}"
log_success "Tables created: ${TABLE_COUNT}"
log_success "PostGIS version: ${POSTGIS_VERSION}"
log_success "Default language: ${DEFAULT_LANG}"
echo ""
log_info "Next steps:"
echo "  1. Start Docker Compose: docker-compose up -d"
echo "  2. Import GeoJSON data: python scripts/import_geojson.py --lang ${DEFAULT_LANG}"
echo "  3. Start web interface: cd web && python -m http.server 8080"
echo "  4. Access API at: http://localhost:3000"
echo "  5. Access PGAdmin at: http://localhost:5050"
echo ""

exit 0