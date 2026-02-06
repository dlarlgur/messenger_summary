#!/bin/bash

# 서버 배포 스크립트
# 사용법: ./server_deploy.sh [aiif|aipf|all]

set -e

# 설정
REMOTE_USER="dksw"
REMOTE_HOST="223.130.151.39"
SSH_KEY="~/.ssh/my_business_nopass"
JAVA_HOME_CMD='export JAVA_HOME=$(/usr/libexec/java_home -v 17)'

# 색상
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

deploy_aiif() {
    log_info "========== AIIF 배포 시작 =========="

    # 1. 빌드
    log_info "AIIF 빌드 중..."
    cd /Users/ghim/my_business/aiif
    eval $JAVA_HOME_CMD
    mvn clean package -DskipTests -q

    # 2. JAR 확인
    if [ ! -f "/Users/ghim/my_business/aiif/target/dksw_aiif.jar" ]; then
        log_error "빌드 실패: JAR 파일이 없습니다."
        exit 1
    fi
    log_info "빌드 완료: $(ls -lh /Users/ghim/my_business/aiif/target/dksw_aiif.jar | awk '{print $5}')"

    # 3. 업로드 (서버 Dockerfile은 aiif-1.0.0.jar 사용)
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/aiif/target"
    scp -i $SSH_KEY /Users/ghim/my_business/aiif/target/dksw_aiif.jar \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/aiif/target/aiif-1.0.0.jar

    # 4. Docker 재시작
    log_info "Docker 컨테이너 재시작 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "cd ~/aiapp/docker && docker compose build --no-cache aiif && docker compose up -d aiif"

    # 5. 로그 확인
    log_info "시작 대기 중 (8초)..."
    sleep 8
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_aiif 2>&1 | grep -i 'started\|error' | tail -5"

    log_info "========== AIIF 배포 완료 =========="
}

deploy_aipf() {
    log_info "========== AIPF 배포 시작 =========="

    # 1. 빌드
    log_info "AIPF 빌드 중..."
    cd /Users/ghim/my_business/aipf
    eval $JAVA_HOME_CMD
    mvn clean package -DskipTests -q

    # 2. JAR 확인
    if [ ! -f "/Users/ghim/my_business/aipf/target/dksw_aipf.jar" ]; then
        log_error "빌드 실패: JAR 파일이 없습니다."
        exit 1
    fi
    log_info "빌드 완료: $(ls -lh /Users/ghim/my_business/aipf/target/dksw_aipf.jar | awk '{print $5}')"

    # 3. 업로드 (서버 Dockerfile은 aipf-1.0.0.jar 사용)
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/aipf/target"
    scp -i $SSH_KEY /Users/ghim/my_business/aipf/target/dksw_aipf.jar \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/aipf/target/aipf-1.0.0.jar

    # 4. Docker 재시작
    log_info "Docker 컨테이너 재시작 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "cd ~/aiapp/docker && docker compose build --no-cache aipf && docker compose up -d aipf"

    # 5. 로그 확인
    log_info "시작 대기 중 (8초)..."
    sleep 8
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_aipf 2>&1 | grep -i 'started\|error' | tail -5"

    log_info "========== AIPF 배포 완료 =========="
}

cleanup_images() {
    log_info "========== 안 쓰는 Docker 이미지 정리 =========="
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker image prune -f && docker images | grep -E 'aipf|aiif' | grep -v 'docker-' | awk '{print \$3}' | xargs -r docker rmi 2>/dev/null || true"
    log_info "정리 완료"
}

show_usage() {
    echo "사용법: $0 [aiif|aipf|all|cleanup]"
    echo ""
    echo "옵션:"
    echo "  aiif    - AIIF 서버만 배포"
    echo "  aipf    - AIPF 서버만 배포"
    echo "  all     - AIIF, AIPF 모두 배포"
    echo "  cleanup - 안 쓰는 Docker 이미지 정리"
    echo ""
    echo "예시:"
    echo "  $0 aiif"
    echo "  $0 all"
}

# 메인
case "$1" in
    aiif)
        deploy_aiif
        ;;
    aipf)
        deploy_aipf
        ;;
    all)
        deploy_aiif
        echo ""
        deploy_aipf
        ;;
    cleanup)
        cleanup_images
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

log_info "배포 완료!"
