-- Create pharma_db database (runs during PostgreSQL init in template1)
-- Note: This script runs in template1 context, so we can create other databases

DROP DATABASE IF EXISTS pharma_db;
CREATE DATABASE pharma_db WITH OWNER = postgres;