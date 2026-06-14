# Stage 1: Build inside an Alpine container with compilers and sqlite3-dev
FROM alpine:latest AS builder
RUN apk add --no-cache build-base g++ openssl-dev sqlite-dev

WORKDIR /build
COPY api_server.asm db_helper.cpp ./

# Compile db_helper and assemble API
RUN g++ -O3 -c db_helper.cpp -o db_helper.o && \
    as -o api_server.o api_server.asm && \
    g++ -no-pie -o api_server_asm_bin api_server.o db_helper.o -lssl -lcrypto -lsqlite3

# Stage 2: Runtime image
FROM alpine:latest
RUN apk add --no-cache libstdc++ libgcc openssl sqlite-libs

WORKDIR /app/experiment7_sql/backend_asm
COPY --from=builder /build/api_server_asm_bin ./

# Create the data directory to hold music.db
RUN mkdir -p /app/data

EXPOSE 8080
CMD ["./api_server_asm_bin"]
