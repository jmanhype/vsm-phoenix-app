# Security Configuration for VSM Phoenix

import Config

# Security settings
config :vsm_phoenix, VsmPhoenix.Infrastructure.Security,
  # Enable/disable security features
  enabled: true,
  
  # Nonce TTL in milliseconds (5 minutes default)
  nonce_ttl_ms: 300_000,
  
  # Timestamp tolerance in milliseconds (1 minute default)
  timestamp_tolerance_ms: 60_000,
  
  # Cleanup interval in milliseconds
  cleanup_interval_ms: 60_000

# AMQP Secure Router settings
config :vsm_phoenix, VsmPhoenix.AMQP.SecureCommandRouter,
  # Enable security by default
  security_enabled: true,
  
  # Allow unsigned messages (for backward compatibility during migration)
  # Set to false in production!
  allow_unsigned: System.get_env("ALLOW_UNSIGNED_MESSAGES", "false") == "true"

# Key rotation settings
config :vsm_phoenix, :security_key_rotation,
  # Enable automatic key rotation
  enabled: false,
  
  # Rotation interval (24 hours)
  interval_hours: 24,
  
  # Grace period for old keys (1 hour)
  grace_period_hours: 1

# Audit settings
config :vsm_phoenix, :security_audit,
  # Log all security events
  log_level: :info,
  
  # Store security events
  store_events: true,
  
  # Events to audit
  audit_events: [
    :message_signed,
    :message_verified,
    :replay_blocked,
    :invalid_signature,
    :timestamp_violation,
    :key_rotated
  ]

# Production overrides
if config_env() == :prod do
  config :vsm_phoenix, VsmPhoenix.Infrastructure.Security,
    # Stricter settings for production
    nonce_ttl_ms: 180_000,  # 3 minutes
    timestamp_tolerance_ms: 30_000  # 30 seconds
    
  config :vsm_phoenix, VsmPhoenix.AMQP.SecureCommandRouter,
    # Never allow unsigned in production
    allow_unsigned: false
    
  config :vsm_phoenix, :security_key_rotation,
    # Enable key rotation in production
    enabled: true
end

# Development overrides  
if config_env() == :dev do
  config :vsm_phoenix, VsmPhoenix.AMQP.SecureCommandRouter,
    # Allow unsigned in development for easier testing
    allow_unsigned: true
end

# Test overrides
if config_env() == :test do
  config :vsm_phoenix, VsmPhoenix.Infrastructure.Security,
    # Shorter TTLs for testing
    nonce_ttl_ms: 10_000,
    timestamp_tolerance_ms: 5_000,
    cleanup_interval_ms: 1_000
end