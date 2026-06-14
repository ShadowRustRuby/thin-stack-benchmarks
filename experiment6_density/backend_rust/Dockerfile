# Stage 1: Build Rust binary
FROM rust:alpine AS builder
RUN apk add --no-cache musl-dev

WORKDIR /build
COPY Cargo.toml ./
COPY src/ ./src/
RUN cargo build --release

# Stage 2: Runtime image
FROM alpine:latest
WORKDIR /app/experiment6_density/backend_rust
COPY --from=builder /build/target/release/api_server_rust ./api_server_rust

# Copy records.csv to matching relative path (../../data/records.csv)
COPY records.csv /app/data/records.csv

EXPOSE 8080
CMD ["./api_server_rust"]
