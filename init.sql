-- Initialize databases for VSM Phoenix
-- This script is run automatically when PostgreSQL container starts

-- Create main development database
CREATE DATABASE vsm_phoenix_dev;

-- Create test database
CREATE DATABASE vsm_phoenix_test;

-- Create EventStore database
CREATE DATABASE vsm_phoenix_eventstore_dev;
CREATE DATABASE vsm_phoenix_eventstore_test;

-- Grant all privileges to postgres user
GRANT ALL PRIVILEGES ON DATABASE vsm_phoenix_dev TO postgres;
GRANT ALL PRIVILEGES ON DATABASE vsm_phoenix_test TO postgres;
GRANT ALL PRIVILEGES ON DATABASE vsm_phoenix_eventstore_dev TO postgres;
GRANT ALL PRIVILEGES ON DATABASE vsm_phoenix_eventstore_test TO postgres;

-- Create extensions needed by the application
\c vsm_phoenix_dev;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

\c vsm_phoenix_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

\c vsm_phoenix_eventstore_dev;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\c vsm_phoenix_eventstore_test;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";