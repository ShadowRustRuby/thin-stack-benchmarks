# Stage 1: Build Rust binary
FROM rust:alpine AS builder
RUN apk add --no-cache musl-dev gcc build-base

WORKDIR /build
COPY Cargo.toml ./
COPY src/ ./src/
RUN cargo build --release

# Stage 2: Runtime image
FROM alpine:latest
WORKDIR /app/experiment7_sql/backend_rust
COPY --from=builder /build/target/release/api_server_rust_sql ./api_server_rust_sql

EXPOSE 8080
CMD ["./api_server_rust_sql"]
