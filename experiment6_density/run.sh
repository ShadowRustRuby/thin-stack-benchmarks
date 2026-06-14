#!/bin/bash
set -e

# Change to the script's directory
cd "$(dirname "$0")"

echo "=== Thin Stack density deployment helper ==="

# 1. Bundle TypeScript frontend using Bun if available
if command -v bun &> /dev/null; then
    echo "[Frontend] Bundling TypeScript client..."
    bun build ./frontend/client.ts --outfile=./frontend/client.js
else
    echo "[Frontend] Warning: Bun is not installed. Skipping compilation (using existing client.js)."
fi

# 2. Check docker connection permissions
if ! docker ps &> /dev/null; then
    echo "[Docker] Socket permission check failed."
    
    # Check if user is in 'docker' group
    if groups "$USER" | grep &>/dev/null '\bdocker\b'; then
        echo "[Docker] You are in the 'docker' group, but the changes are not active in this session."
        echo "Executing the application via newgrp docker..."
        exec newgrp docker <<EONG
docker compose up --build
EONG
    else
        echo "[Docker] Current user '$USER' is not in the docker group."
        echo "Attempting to add '$USER' to the docker group (requires sudo authentication)..."
        sudo usermod -aG docker "$USER"
        echo "[Docker] Successfully added to docker group."
        echo ""
        echo "IMPORTANT: Please log out and back in, or run 'newgrp docker' in your terminal, then run this script again."
        exit 0
    fi
else
    # Permissions are already correct
    echo "[Docker] Access verified. Launching services..."
    docker compose up --build
fi
