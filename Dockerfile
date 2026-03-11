# ─── Build stage ──────────────────────────────────────────────────────────────
FROM dart:stable AS builder

WORKDIR /workspace

# Copy workspace pubspec first for caching
COPY pubspec.yaml ./

# Copy all packages
COPY packages/shared  packages/shared
COPY packages/runner  packages/runner

# Resolve dependencies for the runner (workspace-aware)
WORKDIR /workspace/packages/runner
RUN dart pub get

# Compile to a self-contained native executable
RUN dart compile exe bin/runner.dart -o /runner

# ─── Runtime stage ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /runner /usr/local/bin/runner

# The user passes a bot ZIP via --config
# Example: docker run bot-creator-runner --config /data/bot.zip
# Mount the ZIP using -v /host/path/bot.zip:/data/bot.zip
ENTRYPOINT ["/usr/local/bin/runner"]
CMD ["--help"]
