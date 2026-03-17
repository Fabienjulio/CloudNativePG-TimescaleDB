#!/bin/bash
# =============================================================================
# Database Initialization Script
# =============================================================================
# Sets up the application database with:
#   - TimescaleDB extension
#   - Custom schema execution (if any)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="monitoring"
POD="timescaledb-cluster-1"

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
# Main Initialization
# =============================================================================

print_info "Initializing database..."
echo ""

# Execute any provided SQL scripts
if [ -d "sample-app" ]; then
    for file in schema seed-data; do
        if [ -f "sample-app/$file.sql" ]; then
            echo "Running $file.sql..."
            kubectl exec -i $POD -n $NAMESPACE -- \
                psql -U postgres -d app < sample-app/$file.sql
            echo ""
        fi
    done
fi

# =============================================================================
# Gather Verification Data
# =============================================================================

print_info "Gathering verification data..."

# Get extension info
EXTENSIONS=$(kubectl exec -i $POD -n $NAMESPACE -- \
    psql -U postgres -d app -tAc "
SELECT string_agg(extname || ' ' || extversion, ', ' ORDER BY extname)
FROM pg_extension 
WHERE extname IN ('timescaledb');")

# =============================================================================
# Display Detailed Verification
# =============================================================================

echo ""
echo "📈 Detailed Verification:"
echo "-------------------------"

# Show extensions
kubectl exec -it $POD -n $NAMESPACE -- \
    psql -U postgres -d app -c "
SELECT extname, extversion 
FROM pg_extension 
WHERE extname IN ('timescaledb')
ORDER BY extname;"

echo ""

# =============================================================================
# Success Summary
# =============================================================================

echo ""
echo "=========================================="
print_success "Database Initialization Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  • Extensions: $EXTENSIONS"
echo ""