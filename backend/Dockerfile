# Boardroom Journal Backend Dockerfile
# Multi-stage build for smaller final image

# Build stage
FROM dart:stable AS build

WORKDIR /app

# Copy pubspec files first for dependency caching
COPY pubspec.* ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Compile to native executable
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -r -s /bin/false appuser

WORKDIR /app

# Copy compiled binary from build stage
COPY --from=build /app/bin/server /app/bin/server

# Copy schema for reference (optional, for deployment scripts)
COPY --from=build /app/lib/db/schema.sql /app/schema.sql

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run server
CMD ["/app/bin/server"]
