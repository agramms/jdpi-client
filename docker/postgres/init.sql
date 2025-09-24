-- JDPI Client PostgreSQL initialization script
-- Create databases for development and testing

-- Create test database
CREATE DATABASE jdpi_client_test;

-- Create development database (already created by POSTGRES_DB, but ensure it exists)
-- CREATE DATABASE jdpi_client_development; -- Already created

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE jdpi_client_development TO postgres;
GRANT ALL PRIVILEGES ON DATABASE jdpi_client_test TO postgres;

-- Connect to development database and create table for token storage
\c jdpi_client_development;

-- Create tokens table for development
CREATE TABLE IF NOT EXISTS jdpi_client_tokens (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for expiration cleanup
CREATE INDEX IF NOT EXISTS idx_jdpi_tokens_expires_at ON jdpi_client_tokens(expires_at);

-- Connect to test database and create table for token storage
\c jdpi_client_test;

-- Create tokens table for testing
CREATE TABLE IF NOT EXISTS jdpi_client_tokens (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for expiration cleanup
CREATE INDEX IF NOT EXISTS idx_jdpi_tokens_expires_at ON jdpi_client_tokens(expires_at);

-- Go back to postgres database
\c postgres;