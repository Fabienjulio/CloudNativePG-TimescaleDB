#!/bin/bash
# =============================================================================
# Database Initialization & Verification Script
# =============================================================================
# Ensures TimescaleDB extensions are enabled in the application database and
# runs a self-contained transactional hypertable smoke test.
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="monitoring"
CLUSTER_NAME="timescaledb-cluster"
DATABASE="app"

# =============================================================================
# Helper Functions
# =============================================================================

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}📊 $1${NC}"
}

# =============================================================================
# Resolve Primary Pod
# =============================================================================

PRIMARY_POD=$(kubectl get pod -n "$NAMESPACE" \
    -l "cnpg.io/cluster=${CLUSTER_NAME},cnpg.io/instanceRole=primary" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$PRIMARY_POD" ]; then
    PRIMARY_POD="${CLUSTER_NAME}-1"
fi

if ! kubectl get pod "$PRIMARY_POD" -n "$NAMESPACE" >/dev/null 2>&1; then
    print_error "Primary pod '$PRIMARY_POD' not found in namespace '$NAMESPACE'. Run ./cluster-setup.sh first."
    exit 1
fi

# =============================================================================
# Main Initialization & Smoke Test
# =============================================================================

print_info "Using primary pod: $PRIMARY_POD (database: $DATABASE)"
print_info "Ensuring TimescaleDB extensions are enabled..."

kubectl exec -i "$PRIMARY_POD" -n "$NAMESPACE" -- \
    psql -U postgres -d "$DATABASE" -v ON_ERROR_STOP=1 <<'EOF'
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_available_extensions WHERE name = 'timescaledb_toolkit'
    ) THEN
        CREATE EXTENSION IF NOT EXISTS timescaledb_toolkit CASCADE;
    END IF;
END
$$;
EOF

echo ""
print_info "Running transactional hypertable smoke test..."

kubectl exec -i "$PRIMARY_POD" -n "$NAMESPACE" -- \
    psql -U postgres -d "$DATABASE" -v ON_ERROR_STOP=1 <<'EOF'
BEGIN;
CREATE TABLE ts_smoke_test (
    time TIMESTAMPTZ NOT NULL,
    value DOUBLE PRECISION NOT NULL
);
SELECT create_hypertable('ts_smoke_test', by_range('time'));
INSERT INTO ts_smoke_test (time, value) VALUES (NOW(), 42.0);
SELECT count(*) AS smoke_test_rows FROM ts_smoke_test;
ROLLBACK;
EOF

print_success "Hypertable smoke test passed (rolled back cleanly)"
echo ""

# =============================================================================
# Gather & Display Verification Data
# =============================================================================

print_info "Gathering verification data..."

EXTENSIONS=$(kubectl exec -i "$PRIMARY_POD" -n "$NAMESPACE" -- \
    psql -U postgres -d "$DATABASE" -tAc "
SELECT string_agg(extname || ' ' || extversion, ', ' ORDER BY extname)
FROM pg_extension
WHERE extname IN ('timescaledb', 'timescaledb_toolkit');")

echo ""
echo "📈 Installed Extensions:"
echo "-------------------------"

kubectl exec -i "$PRIMARY_POD" -n "$NAMESPACE" -- \
    psql -U postgres -d "$DATABASE" -c "
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('timescaledb', 'timescaledb_toolkit')
ORDER BY extname;"

echo ""
echo "=========================================="
print_success "Database Initialization Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • Primary pod: $PRIMARY_POD"
echo "  • Database: $DATABASE"
echo "  • Extensions: ${EXTENSIONS:-none}"
echo ""
