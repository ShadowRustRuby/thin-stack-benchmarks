#!/bin/bash
set -e

# Change to the script's directory
cd "$(dirname "$0")"

echo "=== Thin Stack SQL deployment helper (SQLite) ==="

# 1. Bundle TypeScript frontend using Bun if available
if command -v bun &> /dev/null; then
    echo "[Frontend] Bundling TypeScript client..."
    bun build ./frontend/client.ts --outfile=./frontend/client.js
else
    echo "[Frontend] Warning: Bun is not installed. Using existing client.js."
fi

# 2. Check docker connection permissions
if ! docker ps &> /dev/null; then
    echo "[Docker] Socket permission check failed."
    
    if groups "$USER" | grep &>/dev/null '\bdocker\b'; then
        echo "[Docker] You are in the 'docker' group, but the changes are not active."
        echo "Executing via newgrp docker..."
        exec newgrp docker <<EONG
docker compose up --build
EONG
    else
        echo "[Docker] Current user '$USER' is not in the docker group."
        echo "Attempting to add to the docker group (requires sudo)..."
        sudo usermod -aG docker "$USER"
        echo "[Docker] Added. Please run 'newgrp docker' or log out/in, then run this script again."
        exit 0
    fi
else
    echo "[Docker] Access verified. Launching SQL stack..."
    docker compose up --build
fi
