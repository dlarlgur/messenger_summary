#!/bin/bash
set -e

echo "🧹 Cleanup Script"
echo "================="

SERVER_USER="dksw"
SERVER_HOST="223.130.151.39"
SERVER_PATH="/home/dksw/aiapp"
SSH_KEY="$HOME/.ssh/my_business_deploy"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# SSH 명령 설정
if [ -f "$SSH_KEY" ]; then
    SSH_CMD="ssh -i $SSH_KEY"
else
    SSH_CMD="ssh"
fi

echo ""
warning "This will stop all containers and remove images"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

echo ""
echo "🛑 Stopping containers..."
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "cd ${SERVER_PATH}/docker && docker-compose down"

echo ""
echo "🗑️  Removing images..."
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "docker image prune -af"

echo ""
echo "🗑️  Removing unused volumes..."
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "docker volume prune -f"

success "Cleanup completed"
