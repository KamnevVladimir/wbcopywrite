# ================================
# Build stage
# ================================
FROM swift:5.9-jammy as build

WORKDIR /build

# Install OS dependencies
RUN apt-get update -y \
    && apt-get install -y libsqlite3-dev \
    && rm -r /var/lib/apt/lists/*

# Copy Package files
COPY ./Package.* ./

# Resolve dependencies
RUN swift package resolve

# Copy source code
COPY . .

# Build with release configuration
RUN swift build -c release --static-swift-stdlib

# ================================
# Run stage
# ================================
FROM ubuntu:jammy

# Install runtime dependencies
RUN apt-get update -y \
    && apt-get install -y ca-certificates tzdata \
    && rm -r /var/lib/apt/lists/*

# Create app user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app

# Copy built executable and resources
COPY --from=build --chown=vapor:vapor /build/.build/release /app

# Set user
USER vapor:vapor

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the app
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]

