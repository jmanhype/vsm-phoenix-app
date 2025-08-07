# Build stage
ARG ELIXIR_VERSION=1.14.5
ARG OTP_VERSION=27.0
ARG NODE_VERSION=18

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-3.18.4 AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm python3

# Set build environment
ENV MIX_ENV=prod

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
COPY config config

# Install Elixir dependencies
RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

# Copy assets files
COPY assets/package.json assets/package-lock.json ./assets/
COPY priv priv

# Install Node dependencies
WORKDIR /app/assets
RUN npm ci --production

# Copy remaining assets
COPY assets assets

# Build assets
RUN npm run deploy

# Back to app root
WORKDIR /app

# Copy source code
COPY lib lib

# Compile and build release
RUN mix do compile, release

# Runtime stage
FROM alpine:3.18.4 AS runtime

# Install runtime dependencies
RUN apk add --no-cache openssl ncurses-libs libstdc++ ca-certificates

# Create app user
RUN addgroup -g 1000 vsm && \
    adduser -u 1000 -G vsm -s /bin/sh -D vsm

# Set working directory
WORKDIR /app

# Copy release from build stage
COPY --from=build --chown=vsm:vsm /app/_build/prod/rel/vsm_phoenix ./

# Set environment
ENV HOME=/app \
    MIX_ENV=prod \
    PORT=4000 \
    SHELL=/bin/sh

# Expose port
EXPOSE 4000

# Set user
USER vsm

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start the application
CMD ["bin/vsm_phoenix", "start"]