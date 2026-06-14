# Stage 1: Build inside an Alpine container with compilers and sqlite3-dev
FROM alpine:latest AS builder
RUN apk add --no-cache build-base g++ openssl-dev sqlite-dev

WORKDIR /build
COPY api_server.cpp db_helper.cpp ./

# Compile api_server and db_helper
RUN g++ -O3 -c db_helper.cpp -o db_helper.o && \
    g++ -O3 -c api_server.cpp -o api_server.o && \
    g++ -no-pie -o api_server_cpp_bin api_server.o db_helper.o -lssl -lcrypto -lsqlite3

# Stage 2: Runtime image
FROM alpine:latest
RUN apk add --no-cache libstdc++ libgcc openssl sqlite-libs

WORKDIR /app/experiment7_sql/backend_cpp
COPY --from=builder /build/api_server_cpp_bin ./

# Create data directory
RUN mkdir -p /app/data

EXPOSE 8080
CMD ["./api_server_cpp_bin"]
