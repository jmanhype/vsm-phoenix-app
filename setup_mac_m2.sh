#!/bin/bash
# VSM Phoenix - Mac M2 Complete Setup Script
# This script fixes all critical issues and sets up the complete environment

set -e  # Exit on error
set -x  # Print commands

echo "🚀 VSM Phoenix Mac M2 Setup - Complete Fix Script"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 2. Install PostgreSQL
echo -e "${GREEN}Setting up PostgreSQL...${NC}"
brew install postgresql@15
brew services start postgresql@15

# Wait for PostgreSQL to start
sleep 3

# Create database user and database
createuser -s postgres || true
createdb vsm_phoenix_dev || true
createdb vsm_phoenix_test || true

echo -e "${GREEN}✅ PostgreSQL installed and running${NC}"

# 3. Install RabbitMQ
echo -e "${GREEN}Setting up RabbitMQ...${NC}"
brew install rabbitmq
brew services start rabbitmq

# Wait for RabbitMQ to start
sleep 5

# Enable RabbitMQ management plugin
export PATH="/opt/homebrew/sbin:$PATH"
rabbitmq-plugins enable rabbitmq_management

echo -e "${GREEN}✅ RabbitMQ installed and running (Management UI: http://localhost:15672)${NC}"

# 4. Install Xcode Command Line Tools (for C++ headers needed by ML deps)
echo -e "${GREEN}Installing Xcode Command Line Tools...${NC}"
xcode-select --install 2>/dev/null || true

# 5. Install additional dependencies
echo -e "${GREEN}Installing additional dependencies...${NC}"
brew install cmake
brew install bazel
brew install python@3.11
brew install gcc
brew install llvm

# Set up environment variables for compilation
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
export CC="/opt/homebrew/opt/llvm/bin/clang"
export CXX="/opt/homebrew/opt/llvm/bin/clang++"

# 6. Install Elixir and Erlang if not installed
if ! command -v elixir &> /dev/null; then
    echo -e "${GREEN}Installing Erlang and Elixir...${NC}"
    brew install erlang
    brew install elixir
fi

# 7. Create .env file with proper configurations
echo -e "${GREEN}Creating .env configuration...${NC}"
cat > .env <<EOF
# Database Configuration
DATABASE_URL=ecto://postgres:postgres@localhost/vsm_phoenix_dev
PGUSER=postgres
PGPASSWORD=postgres
PGDATABASE=vsm_phoenix_dev
PGHOST=localhost
PGPORT=5432

# RabbitMQ Configuration
RABBITMQ_URL=amqp://guest:guest@localhost:5672
RABBITMQ_HOST=localhost
RABBITMQ_PORT=5672
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest
RABBITMQ_VHOST=/

# Phoenix Configuration
PHX_SERVER=true
SECRET_KEY_BASE=VSM_PHOENIX_SECRET_KEY_BASE_DEV_VERY_LONG_STRING_FOR_SECURITY_WITH_64_BYTES_MIN_REQUIREMENT_HERE_FOR_MAC_M2

# Telegram Bot (Optional - add your token if you have one)
TELEGRAM_BOT_TOKEN=
TELEGRAM_WEBHOOK_URL=

# LLM API Keys (Optional - add your keys if you have them)
OPENAI_API_KEY=
ANTHROPIC_API_KEY=

# EventStore Configuration
EVENTSTORE_URL=postgres://postgres:postgres@localhost/vsm_phoenix_eventstore_dev

# ML Compilation Flags for Mac M2
EXLA_TARGET=METAL
XLA_TARGET=arm64-apple-darwin
EOF

echo -e "${GREEN}✅ Environment configuration created${NC}"

# 8. Create EventStore database
createdb vsm_phoenix_eventstore_dev || true
createdb vsm_phoenix_eventstore_test || true

echo -e "${GREEN}✅ EventStore databases created${NC}"

# 9. Source the environment
export $(cat .env | grep -v '^#' | xargs)

echo -e "${YELLOW}Environment setup complete!${NC}"
echo ""
echo "Next steps to run manually:"
echo "1. cd vsm_phoenix_app"
echo "2. source .env"
echo "3. mix deps.get"
echo "4. mix ecto.create"
echo "5. mix ecto.migrate"
echo "6. mix phx.server"
echo ""
echo "Services running:"
echo "- PostgreSQL: localhost:5432"
echo "- RabbitMQ: localhost:5672 (Management: http://localhost:15672)"
echo ""
echo "To check service status:"
echo "brew services list"