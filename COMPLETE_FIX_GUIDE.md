# 🚀 VSM Phoenix - Complete Mac M2 Fix Guide

## 🔴 Quick Fix Commands (Run These First!)

### Option 1: Using Homebrew (Recommended for Mac M2)
```bash
# 1. Install and start services
brew install postgresql@15 rabbitmq
brew services start postgresql@15
brew services start rabbitmq

# 2. Create databases
createdb vsm_phoenix_dev
createdb vsm_phoenix_test
createdb vsm_phoenix_eventstore_dev

# 3. Install Xcode tools for ML deps
xcode-select --install

# 4. Run the setup script
chmod +x setup_mac_m2.sh
./setup_mac_m2.sh

# 5. Start Phoenix
source .env
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

### Option 2: Using Docker (Alternative)
```bash
# 1. Start all services with Docker
docker-compose -f docker-compose.mac.yml up -d

# 2. Wait for services to be ready
sleep 10

# 3. Run Phoenix
export DATABASE_URL=ecto://postgres:postgres@localhost/vsm_phoenix_dev
export RABBITMQ_URL=amqp://guest:guest@localhost:5672
mix deps.get
mix ecto.create
mix ecto.migrate
mix phx.server
```

## 📋 Complete Issue Resolution

### 1. ✅ PostgreSQL Not Running
**Fixed by:**
- Homebrew installation with auto-start
- Docker alternative with health checks
- Connection retry logic in Repo configuration

### 2. ✅ RabbitMQ Not Running  
**Fixed by:**
- Homebrew installation with management plugin
- Docker alternative with management UI
- Graceful fallback in ConnectionManager
- Retry logic with 5 attempts

### 3. ✅ ML Dependencies (C++ Headers)
**Fixed by:**
- Xcode Command Line Tools installation
- LLVM/Clang for proper compilation
- Metal acceleration for M2 chip
- Environment variables for EXLA

### 4. ✅ Application Startup Crash
**Fixed by:**
- Repo re-enabled with proper config
- RabbitMQ connection with retry logic
- Graceful degradation if services unavailable
- Proper supervision tree ordering

### 5. ✅ Code Warnings
**Will be fixed by running:**
```bash
# Fix deprecated Logger warnings
find lib -name "*.ex" -exec sed -i '' 's/Logger\.warn(/Logger.warning(/g' {} \;

# Format all code
mix format
```

## 🎯 Environment Variables (.env file)
```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost/vsm_phoenix_dev
PGUSER=postgres
PGPASSWORD=postgres

# RabbitMQ
RABBITMQ_URL=amqp://guest:guest@localhost:5672

# Phoenix
SECRET_KEY_BASE=VSM_PHOENIX_SECRET_KEY_BASE_DEV_VERY_LONG_STRING_FOR_SECURITY_WITH_64_BYTES_MIN_REQUIREMENT_HERE_FOR_MAC_M2

# ML for M2
EXLA_TARGET=METAL
XLA_TARGET=arm64-apple-darwin
```

## 🔧 Verification Commands

### Check Services Status
```bash
# PostgreSQL
pg_isready
psql -U postgres -l

# RabbitMQ
rabbitmqctl status
curl -u guest:guest http://localhost:15672/api/overview

# Homebrew services
brew services list
```

### Test Phoenix
```bash
# Basic test
mix test

# Interactive console
iex -S mix

# Check all supervisors
:observer.start()
```

## 🚨 Troubleshooting

### If PostgreSQL fails:
```bash
# Reset PostgreSQL
brew services stop postgresql@15
rm -rf /opt/homebrew/var/postgresql@15
brew services start postgresql@15
createdb vsm_phoenix_dev
```

### If RabbitMQ fails:
```bash
# Reset RabbitMQ
brew services stop rabbitmq
rm -rf /opt/homebrew/var/lib/rabbitmq
brew services start rabbitmq
```

### If ML deps fail:
```bash
# Clean and rebuild
mix deps.clean --all
rm -rf _build deps
mix deps.get
EXLA_TARGET=METAL mix deps.compile
```

## 📊 Expected Output When Working

```
[info] Running VsmPhoenixWeb.Endpoint with cowboy 2.10.0 at 127.0.0.1:4000 (http)
[info] Access VsmPhoenixWeb.Endpoint at http://localhost:4000
[info] ✅ Connected to RabbitMQ successfully!
[info] 📋 VSM topology created with bidirectional support
[watch] build finished, watching for changes...
```

## 🎉 Success Indicators

1. **PostgreSQL**: `pg_isready` returns "accepting connections"
2. **RabbitMQ**: Management UI accessible at http://localhost:15672
3. **Phoenix**: Server running at http://localhost:4000
4. **Dashboard**: Real-time events at http://localhost:4000/events/dashboard

## 🔗 Service URLs

- **Phoenix App**: http://localhost:4000
- **RabbitMQ Management**: http://localhost:15672 (guest/guest)
- **PostgreSQL**: localhost:5432
- **LiveDashboard**: http://localhost:4000/dev/dashboard

## 💡 Pro Tips for Mac M2

1. **Use Metal acceleration** for ML: `EXLA_TARGET=METAL`
2. **Homebrew on M2** installs to `/opt/homebrew` not `/usr/local`
3. **Rosetta not needed** - everything runs native ARM64
4. **Docker Desktop** alternative: Use native services via Homebrew for better performance

## 🚀 Next Steps After Fix

1. Test all Phase 2 endpoints
2. Verify ML capabilities with Metal acceleration
3. Check event streaming dashboard
4. Monitor RabbitMQ queues in management UI
5. Run the complete test suite

---

**Note**: This fix guide is specifically optimized for Mac M2 (Apple Silicon) systems with 32GB RAM.