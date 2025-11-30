#!/bin/bash

# PostgreSQL Load Test Script
# Generates database activity for Grafana metrics collection
# Author: Jian Ouyang (jian.ouyang@sapns2.com)

set -e

# Configuration
NAMESPACE="postgres"
POD_NAME="postgres-0"
CONTAINER_NAME="postgres"
DB_NAME="testdb"
DB_USER="postgres"
TABLE_NAME="metrics_test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== PostgreSQL Load Test Script ===${NC}"
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo "Database: $DB_NAME"
echo "Table: $TABLE_NAME"
echo ""

# Function to execute SQL commands
execute_sql() {
    local sql="$1"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -c "$CONTAINER_NAME" -- \
        psql -U "$DB_USER" -d "$DB_NAME" -c "$sql"
}

# Function to execute SQL and return output
execute_sql_output() {
    local sql="$1"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -c "$CONTAINER_NAME" -- \
        psql -U "$DB_USER" -d "$DB_NAME" -t -c "$sql"
}

# Check if pod is running
echo -e "${YELLOW}Checking if PostgreSQL pod is running...${NC}"
if ! kubectl get pod -n "$NAMESPACE" "$POD_NAME" &>/dev/null; then
    echo -e "${RED}Error: Pod $POD_NAME not found in namespace $NAMESPACE${NC}"
    exit 1
fi

POD_STATUS=$(kubectl get pod -n "$NAMESPACE" "$POD_NAME" -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${RED}Error: Pod $POD_NAME is not running (status: $POD_STATUS)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Pod is running${NC}"

# Check if table exists
echo -e "${YELLOW}Checking if table $TABLE_NAME exists...${NC}"
TABLE_EXISTS=$(execute_sql_output "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '$TABLE_NAME');" | tr -d ' ')

if [ "$TABLE_EXISTS" = "f" ]; then
    echo -e "${YELLOW}Table $TABLE_NAME does not exist. Creating...${NC}"

    # Create table
    execute_sql "
    CREATE TABLE $TABLE_NAME (
        id SERIAL PRIMARY KEY,
        event_type VARCHAR(50) NOT NULL,
        message TEXT,
        value INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(id)
    );
    CREATE INDEX idx_${TABLE_NAME}_created_at ON $TABLE_NAME(created_at);
    CREATE INDEX idx_${TABLE_NAME}_event_type ON $TABLE_NAME(event_type);
    "

    echo -e "${GREEN}✓ Table $TABLE_NAME created successfully${NC}"
else
    echo -e "${GREEN}✓ Table $TABLE_NAME already exists${NC}"
fi

# Get current max ID to avoid duplicates
echo -e "${YELLOW}Getting current max ID...${NC}"
MAX_ID=$(execute_sql_output "SELECT COALESCE(MAX(id), 0) FROM $TABLE_NAME;" | tr -d ' ')
echo "Current max ID: $MAX_ID"

# Insert test records
echo -e "${YELLOW}Inserting test records...${NC}"

RECORD_COUNT=10
START_ID=$((MAX_ID + 1))

for i in $(seq 1 $RECORD_COUNT); do
    EVENT_TYPES=("login" "logout" "purchase" "view" "search" "click" "error" "warning")
    EVENT_TYPE=${EVENT_TYPES[$((RANDOM % ${#EVENT_TYPES[@]}))]}
    VALUE=$((RANDOM % 1000))
    MESSAGE="Test event $i - $(date +%s)"

    execute_sql "
    INSERT INTO $TABLE_NAME (event_type, message, value)
    VALUES ('$EVENT_TYPE', '$MESSAGE', $VALUE);
    " > /dev/null

    echo "  Inserted record $i: $EVENT_TYPE (value: $VALUE)"
done

echo -e "${GREEN}✓ Inserted $RECORD_COUNT records successfully${NC}"

# Perform various operations to generate metrics
echo -e "${YELLOW}Performing database operations to generate metrics...${NC}"

# SELECT operations
echo "  Running SELECT queries..."
execute_sql_output "SELECT COUNT(*) FROM $TABLE_NAME;" > /dev/null
execute_sql_output "SELECT event_type, COUNT(*) FROM $TABLE_NAME GROUP BY event_type;" > /dev/null
execute_sql_output "SELECT * FROM $TABLE_NAME ORDER BY created_at DESC LIMIT 10;" > /dev/null

# UPDATE operations
echo "  Running UPDATE operations..."
execute_sql "UPDATE $TABLE_NAME SET value = value + 1 WHERE event_type = 'purchase';" > /dev/null
execute_sql "UPDATE $TABLE_NAME SET message = message || ' [updated]' WHERE id % 3 = 0;" > /dev/null

# Transaction operations
echo "  Running transaction operations..."
execute_sql "
BEGIN;
UPDATE $TABLE_NAME SET value = value * 2 WHERE event_type = 'click';
SELECT pg_sleep(0.1);
COMMIT;
" > /dev/null

# Aggregate queries
echo "  Running aggregate queries..."
execute_sql_output "SELECT event_type, AVG(value) as avg_value FROM $TABLE_NAME GROUP BY event_type;" > /dev/null
execute_sql_output "SELECT DATE_TRUNC('minute', created_at) as minute, COUNT(*) FROM $TABLE_NAME GROUP BY minute;" > /dev/null

echo -e "${GREEN}✓ Database operations completed${NC}"

# Display statistics
echo ""
echo -e "${GREEN}=== Database Statistics ===${NC}"
echo "Total records:"
execute_sql "SELECT COUNT(*) as total_records FROM $TABLE_NAME;"

echo ""
echo "Records by event type:"
execute_sql "SELECT event_type, COUNT(*) as count FROM $TABLE_NAME GROUP BY event_type ORDER BY count DESC;"

echo ""
echo "Recent records:"
execute_sql "SELECT id, event_type, value, created_at FROM $TABLE_NAME ORDER BY created_at DESC LIMIT 5;"

echo ""
echo "Database size:"
execute_sql "SELECT pg_size_pretty(pg_database_size('$DB_NAME')) as database_size;"

echo ""
echo "Table size:"
execute_sql "SELECT pg_size_pretty(pg_total_relation_size('$TABLE_NAME')) as table_size;"

echo ""
echo -e "${GREEN}=== Load test completed successfully ===${NC}"
echo "You can now view metrics in Grafana for:"
echo "  - Connection count"
echo "  - Transaction rates (commits/rollbacks)"
echo "  - Tuples inserted/updated/deleted"
echo "  - Cache hit ratio"
echo "  - Database and table sizes"
