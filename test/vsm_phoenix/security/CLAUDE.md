# Security Test Directory

Cryptographic security layer test suites.

## Files in this directory:

- `crypto_layer_test.exs` - Cryptographic operations and security tests

## Purpose:
Validates the Phase 2 cryptographic security implementation:
- AES-256-GCM encryption/decryption
- HMAC authentication
- Key rotation mechanisms
- Secure communication protocols
- Access control validation

## Test Coverage:

### Encryption Tests
- Message encryption with AES-256-GCM
- Proper IV/nonce generation
- Authentication tag validation
- Large message handling

### Key Management Tests
- Key generation entropy
- Key rotation workflows
- Key expiration handling
- Secure key storage

### Authentication Tests
- HMAC signature generation
- Signature verification
- Replay attack prevention
- Token expiration

### Integration Tests
- Secure agent communication
- Encrypted CRDT synchronization
- Protected telemetry channels
- Secure MCP tool invocation

## Running Tests:
```bash
# Run security tests
mix test test/vsm_phoenix/security

# With crypto benchmarks
mix test test/vsm_phoenix/security --include benchmark
```

## Security Test Patterns:
- Always test both success and failure paths
- Include timing attack resistance tests
- Verify proper error messages (no info leakage)
- Test with invalid/malformed inputs
- Ensure deterministic test outcomes