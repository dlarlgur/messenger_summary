#!/usr/bin/env bash
# DK Software homepage — remote build & deploy
# Rsync source -> server -> docker build -> swap container
set -euo pipefail

SERVER="dksw@223.130.151.39"
REMOTE_DIR="/home/dksw/aiapp/apps/dksw_homepage"
IMAGE="aiapp/dksw_homepage:latest"
CONTAINER="aiapp_dksw_homepage"
NETWORK="docker_aiapp_network"
PORT=3100

here="$(cd "$(dirname "$0")" && pwd)"

echo "▶ Syncing source to $SERVER:$REMOTE_DIR ..."
ssh -o StrictHostKeyChecking=no "$SERVER" "mkdir -p $REMOTE_DIR"
rsync -az --delete \
  --exclude node_modules --exclude .next --exclude .git \
  --exclude .DS_Store --exclude '.env*' \
  -e "ssh -o StrictHostKeyChecking=no" \
  "$here/" "$SERVER:$REMOTE_DIR/"

echo "▶ Building image on server..."
ssh -o StrictHostKeyChecking=no "$SERVER" bash -s <<EOF
  set -e
  cd $REMOTE_DIR
  docker build -t $IMAGE .
  docker rm -f $CONTAINER 2>/dev/null || true
  docker run -d \
    --name $CONTAINER \
    --restart unless-stopped \
    --network $NETWORK \
    -e NODE_ENV=production \
    -e PORT=$PORT \
    $IMAGE
  sleep 2
  docker ps --filter "name=$CONTAINER" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
EOF

echo "✓ Container up. Verifying internal health..."
ssh -o StrictHostKeyChecking=no "$SERVER" "docker exec aiapp_nginx wget -q -O- http://$CONTAINER:$PORT/ | head -c 80 && echo"
echo "✓ Ready. Next: run nginx.patch.sh to route dksw4.com / to this container."
