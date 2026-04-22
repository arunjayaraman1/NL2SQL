#!/bin/bash
# Create pharma_db database

set -e

echo "Initializing Pharma database..."

# Connect to default postgres database and create pharma_db
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres <<-EOSQL
    DROP DATABASE IF EXISTS pharma_db;
    CREATE DATABASE pharma_db WITH OWNER = postgres;
EOSQL

echo "Pharma database created successfully"