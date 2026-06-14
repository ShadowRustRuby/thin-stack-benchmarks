# Stage 1: Build inside an Alpine container with compilers
FROM alpine:latest AS builder
RUN apk add --no-cache build-base g++ openssl-dev

WORKDIR /build
COPY api_server.asm parser_helper.cpp ./

# Assemble and compile the backend server
RUN g++ -O3 -c parser_helper.cpp -o parser_helper.o && \
    as -o api_server.o api_server.asm && \
    g++ -no-pie -o api_server_asm_bin api_server.o parser_helper.o -lssl -lcrypto

# Stage 2: Runtime image
FROM alpine:latest
RUN apk add --no-cache libstdc++ libgcc openssl

WORKDIR /app/experiment6_density/backend
COPY --from=builder /build/api_server_asm_bin ./

# Copy records.csv to matching relative path (../../data/records.csv)
COPY records.csv /app/data/records.csv

EXPOSE 8080
CMD ["./api_server_asm_bin"]
