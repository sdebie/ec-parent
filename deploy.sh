#!/bin/bash
# Update local clones from GitHub
# (Assumes your PAT or SSH keys are already configured)
cd ec-infra && git pull && cd ..
cd ec-backend && git pull && cd ..
cd ec-frontend && git pull && cd ..

# Stop and remove old containers/orphans to ensure a clean slate
docker compose down --remove-orphans

# Rebuild and start in detached mode
# The --build flag ensures your local changes in ec-backend and ec-frontend are compiled
docker compose up -d --build

# Optional: Prune unused images to save space on your Proxmox VM
docker image prune -fls -l
