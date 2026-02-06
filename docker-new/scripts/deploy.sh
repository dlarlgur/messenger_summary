#!/bin/bash
set -e

echo "🚀 AI Platform Deployment Script"
echo "=================================="

# 서버 정보
SERVER_USER="dksw"
SERVER_HOST="223.130.151.39"
SERVER_PATH="/home/dksw/aiapp"
SSH_KEY="$HOME/.ssh/my_business_deploy"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 함수: 에러 메시지
error() {
    echo -e "${RED}❌ Error: $1${NC}"
    exit 1
}

# 함수: 성공 메시지
success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 함수: 경고 메시지
warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 스크립트 디렉토리 기준 설정
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# 1. JAR 파일 존재 확인
echo ""
echo "📦 Checking JAR files..."
if [ ! -f "$BASE_DIR/apps/aiif/target/aiif-1.0.0.jar" ]; then
    error "aiif-1.0.0.jar not found in $BASE_DIR/apps/aiif/target/"
fi
if [ ! -f "$BASE_DIR/apps/aipf/target/aipf-1.0.0.jar" ]; then
    error "aipf-1.0.0.jar not found in $BASE_DIR/apps/aipf/target/"
fi
success "JAR files found"
success "JAR files copied"

# 3. SSH 연결 테스트
echo ""
echo "🔌 Testing SSH connection..."
if [ -f "$SSH_KEY" ]; then
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_HOST} exit 2>/dev/null
    if [ $? -eq 0 ]; then
        SSH_CMD="ssh -i $SSH_KEY"
        SCP_CMD="scp -i $SSH_KEY -r"
        success "SSH key authentication working"
    else
        warning "SSH key auth failed, will use password"
        SSH_CMD="ssh"
        SCP_CMD="scp -r"
    fi
else
    warning "SSH key not found at $SSH_KEY, will use password"
    SSH_CMD="ssh"
    SCP_CMD="scp -r"
fi

# 4. 서버 디렉토리 생성
echo ""
echo "📁 Creating server directories..."
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "mkdir -p ${SERVER_PATH}/{config/{env,app/{aiif,aipf},nginx/conf.d,mysql,redis},docker,data/{mysql,redis,logs/{aiif,aipf}},apps/{aiif/target,aipf/target}}" || error "Failed to create directories"
success "Directories created"

# 5. 설정 파일 전송
echo ""
echo "📤 Uploading configuration files..."
$SCP_CMD $BASE_DIR/config/env ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/config/ || error "Failed to upload env files"
$SCP_CMD $BASE_DIR/config/app ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/config/ || error "Failed to upload app configs"
$SCP_CMD $BASE_DIR/config/nginx ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/config/ || error "Failed to upload nginx configs"
$SCP_CMD $BASE_DIR/config/mysql ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/config/ || error "Failed to upload mysql configs"
$SCP_CMD $BASE_DIR/config/redis ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/config/ || error "Failed to upload redis configs"
success "Configuration files uploaded"

# 6. Docker 파일 전송
echo ""
echo "📤 Uploading Docker files..."
$SCP_CMD $BASE_DIR/docker/docker-compose.yml ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/docker/ || error "Failed to upload docker-compose.yml"
success "Docker files uploaded"

# 7. 애플리케이션 파일 전송
echo ""
echo "📤 Uploading application files..."
$SCP_CMD $BASE_DIR/apps/aiif/Dockerfile ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/apps/aiif/ || error "Failed to upload aiif Dockerfile"
$SCP_CMD $BASE_DIR/apps/aiif/target/aiif-1.0.0.jar ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/apps/aiif/target/ || error "Failed to upload aiif JAR"
$SCP_CMD $BASE_DIR/apps/aipf/Dockerfile ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/apps/aipf/ || error "Failed to upload aipf Dockerfile"
$SCP_CMD $BASE_DIR/apps/aipf/target/aipf-1.0.0.jar ${SERVER_USER}@${SERVER_HOST}:${SERVER_PATH}/apps/aipf/target/ || error "Failed to upload aipf JAR"
success "Application files uploaded"

# 8. 기존 컨테이너 중지
echo ""
echo "🛑 Stopping existing containers..."
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "cd ${SERVER_PATH}/docker && docker-compose down" 2>/dev/null || warning "No existing containers to stop"

# 9. Docker Compose 실행
echo ""
echo "🐳 Starting Docker containers..."
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "cd ${SERVER_PATH}/docker && docker-compose up -d --build" || error "Failed to start containers"
success "Containers started"

# 10. 컨테이너 상태 확인
echo ""
echo "📊 Checking container status..."
sleep 5
$SSH_CMD ${SERVER_USER}@${SERVER_HOST} "cd ${SERVER_PATH}/docker && docker-compose ps"

echo ""
echo "=================================="
success "Deployment completed successfully!"
echo ""
echo "📍 Service URLs:"
echo "   - AIIF API: http://${SERVER_HOST}:1024"
echo "   - AIPF API: http://${SERVER_HOST}:2022"
echo "   - Nginx: http://${SERVER_HOST}:80"
echo ""
echo "🔍 To check logs:"
echo "   ssh ${SERVER_USER}@${SERVER_HOST}"
echo "   cd ${SERVER_PATH}/docker"
echo "   docker-compose logs -f"
