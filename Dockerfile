# Dockerfile for VSM Phoenix Application
# Multi-stage build for optimal production image

#############
# Build Stage
#############
FROM elixir:1.16-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    nodejs \
    yarn \
    python3 \
    python3-dev \
    py3-pip \
    curl

# Set environment variables
ENV MIX_ENV=prod \
    LANG=C.UTF-8

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy assets
COPY assets/package.json assets/yarn.lock ./assets/
WORKDIR /app/assets
RUN yarn install --frozen-lockfile

# Copy application code
WORKDIR /app
COPY . .

# Build assets
WORKDIR /app/assets
RUN yarn build

# Build release
WORKDIR /app
RUN mix assets.deploy
RUN mix phx.digest
RUN mix compile
RUN mix release

#############
# Runtime Stage
#############
FROM alpine:3.18 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    curl \
    bash \
    postgresql-client \
    libstdc++

# Create app user
RUN addgroup -g 1000 -S vsm && \
    adduser -u 1000 -S vsm -G vsm

# Create app directory
WORKDIR /app

# Create directories for ML models and logs
RUN mkdir -p /opt/vsm_phoenix/ml_models && \
    mkdir -p /opt/vsm_phoenix/ml_checkpoints && \
    mkdir -p /app/logs && \
    chown -R vsm:vsm /opt/vsm_phoenix && \
    chown -R vsm:vsm /app

# Copy the release from builder stage
COPY --from=builder --chown=vsm:vsm /app/_build/prod/rel/vsm_phoenix ./

# Switch to app user
USER vsm

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:4000/health || exit 1

# Environment variables
ENV HOME=/app \
    MIX_ENV=prod \
    PORT=4000 \
    SHELL=/bin/bash

# Start command
CMD ["./bin/vsm_phoenix", "start"]