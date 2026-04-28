#!/bin/bash

# 서버 배포 스크립트
# 사용법: ./server_deploy.sh [aiif|aipf|all]
#
# AIIF/AIPF: blue/green 전환 후 ~/aiapp/config/nginx/conf.d/aiapp.conf 업스트림을
#           방금 띄운 색(aiapp_*_${DEPLOY})으로 맞추고 nginx reload 한다.
#           (이걸 빼면 옛 컨테이너로 프록시되어 API 502·로그 안 쌓임)

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

    # 3. 업로드
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/aiif/target"
    scp -i $SSH_KEY /Users/ghim/my_business/aiif/target/dksw_aiif.jar \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/aiif/target/aiif-1.0.0.jar

    # 4. Blue/Green 무중단 배포
    log_info "Blue/Green 배포 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
        set -e
        cd ~/aiapp/docker

        BLUE_RUNNING=$(docker inspect --format='{{.State.Running}}' aiapp_aiif_blue 2>/dev/null || echo "false")
        if [ "$BLUE_RUNNING" = "true" ]; then
            DEPLOY="green"; OLD="blue"
        else
            DEPLOY="blue"; OLD="green"
        fi
        echo "[AIIF] deploying → aiif_${DEPLOY} (stopping aiif_${OLD})"

        docker compose build --no-cache aiif_${DEPLOY}
        docker compose up -d aiif_${DEPLOY}

        echo "[AIIF] waiting for healthy..."
        for i in $(seq 1 30); do
            STATUS=$(docker inspect --format='{{.State.Health.Status}}' aiapp_aiif_${DEPLOY} 2>/dev/null || echo "none")
            [ "$STATUS" = "healthy" ] && echo "[AIIF] healthy!" && break
            [ $i -eq 30 ] && echo "[AIIF] health check timeout, rolling back" && docker compose stop aiif_${DEPLOY} && exit 1
            sleep 3
        done

        # nginx 가 새 컨테이너로 프록시하도록 반드시 전환 (안 하면 죽은 색으로 붙어 502·로그 없음)
        NGINX_CONF="$HOME/aiapp/config/nginx/conf.d/aiapp.conf"
        if [ -f "$NGINX_CONF" ]; then
            cp -a "$NGINX_CONF" "$NGINX_CONF.bak.deploy.$(date +%Y%m%d%H%M%S)"
            sed -i "s/server aiapp_aiif_[a-z]*:1309;/server aiapp_aiif_${DEPLOY}:1309;/g" "$NGINX_CONF"
            if ! grep -q "server aiapp_aiif_${DEPLOY}:1309" "$NGINX_CONF"; then
                echo "[AIIF] ERROR: nginx upstream 치환 실패. $NGINX_CONF 의 aiif 줄(server aiapp_aiif_*.1309) 확인"
                exit 1
            fi
            docker exec aiapp_nginx nginx -t
            docker exec aiapp_nginx nginx -s reload
            echo "[AIIF] nginx upstream → aiapp_aiif_${DEPLOY}:1309"
        else
            echo "[AIIF] WARN: nginx 설정 없음: $NGINX_CONF"
        fi

        docker compose stop aiif_${OLD} 2>/dev/null || true
        echo "[AIIF] stopped aiif_${OLD}"
ENDSSH

    # 5. 로그 확인 (실제 떠 있는 인스턴스만)
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        'C=$(docker ps --filter name=aiapp_aiif_ --format "{{.Names}}" | head -1); echo "[AIIF] active: $C"; docker logs "$C" 2>&1 | grep -iE "started|error" | tail -5' 2>/dev/null || true

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

    # 3. 업로드
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/aipf/target"
    scp -i $SSH_KEY /Users/ghim/my_business/aipf/target/dksw_aipf.jar \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/aipf/target/aipf-1.0.0.jar

    # 4. Blue/Green 무중단 배포
    log_info "Blue/Green 배포 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
        set -e
        cd ~/aiapp/docker

        BLUE_RUNNING=$(docker inspect --format='{{.State.Running}}' aiapp_aipf_blue 2>/dev/null || echo "false")
        if [ "$BLUE_RUNNING" = "true" ]; then
            DEPLOY="green"; OLD="blue"
        else
            DEPLOY="blue"; OLD="green"
        fi
        echo "[AIPF] deploying → aipf_${DEPLOY} (stopping aipf_${OLD})"

        docker compose build --no-cache aipf_${DEPLOY}
        docker compose up -d aipf_${DEPLOY}

        echo "[AIPF] waiting for healthy..."
        for i in $(seq 1 30); do
            STATUS=$(docker inspect --format='{{.State.Health.Status}}' aiapp_aipf_${DEPLOY} 2>/dev/null || echo "none")
            [ "$STATUS" = "healthy" ] && echo "[AIPF] healthy!" && break
            [ $i -eq 30 ] && echo "[AIPF] health check timeout, rolling back" && docker compose stop aipf_${DEPLOY} && exit 1
            sleep 3
        done

        # nginx 가 새 컨테이너로 프록시하도록 반드시 전환
        NGINX_CONF="$HOME/aiapp/config/nginx/conf.d/aiapp.conf"
        if [ -f "$NGINX_CONF" ]; then
            cp -a "$NGINX_CONF" "$NGINX_CONF.bak.deploy.$(date +%Y%m%d%H%M%S)"
            sed -i "s/server aiapp_aipf_[a-z]*:8081;/server aiapp_aipf_${DEPLOY}:8081;/g" "$NGINX_CONF"
            if ! grep -q "server aiapp_aipf_${DEPLOY}:8081" "$NGINX_CONF"; then
                echo "[AIPF] ERROR: nginx upstream 치환 실패. $NGINX_CONF 의 aipf 줄(server aiapp_aipf_*.8081) 확인"
                exit 1
            fi
            docker exec aiapp_nginx nginx -t
            docker exec aiapp_nginx nginx -s reload
            echo "[AIPF] nginx upstream → aiapp_aipf_${DEPLOY}:8081"
        else
            echo "[AIPF] WARN: nginx 설정 없음: $NGINX_CONF"
        fi

        docker compose stop aipf_${OLD} 2>/dev/null || true
        echo "[AIPF] stopped aipf_${OLD}"
ENDSSH

    # 5. 로그 확인 (실제 떠 있는 인스턴스만)
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        'C=$(docker ps --filter name=aiapp_aipf_ --format "{{.Names}}" | head -1); echo "[AIPF] active: $C"; docker logs "$C" 2>&1 | grep -iE "started|error" | tail -5' 2>/dev/null || true

    log_info "========== AIPF 배포 완료 =========="
}

deploy_kapt() {
    log_info "========== KAPT 배포 시작 =========="

    # 1. 빌드
    log_info "KAPT 빌드 중..."
    cd /Users/ghim/my_business/kapt
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    nvm use 20
    npm run build

    # 2. 빌드 확인
    if [ ! -d "/Users/ghim/my_business/kapt/dist" ]; then
        log_error "빌드 실패: dist 폴더가 없습니다."
        exit 1
    fi
    log_info "빌드 완료: $(du -sh /Users/ghim/my_business/kapt/dist | awk '{print $1}')"

    # 3. 업로드
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/kapt"
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        /Users/ghim/my_business/kapt/dist/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/kapt/dist/
    # 정적 리소스 (public) 동기화 – charge.html 등 빌드 시 필요한 파일 포함
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        /Users/ghim/my_business/kapt/public/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/kapt/public/
    rsync -avz \
        -e "ssh -i $SSH_KEY" \
        /Users/ghim/my_business/kapt/server.js \
        /Users/ghim/my_business/kapt/package.json \
        /Users/ghim/my_business/kapt/package-lock.json \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/kapt/
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        /Users/ghim/my_business/kapt/src/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/kapt/src/

    # 4. Docker 재시작
    log_info "Docker 컨테이너 재시작 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "cd ~/aiapp/docker && docker compose build --no-cache kapt && docker compose up -d --force-recreate kapt"

    # 5. 로그 확인
    log_info "시작 대기 중 (8초)..."
    sleep 8
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_kapt 2>&1 | grep -i 'started\|error\|listening' | tail -5"

    log_info "========== KAPT 배포 완료 =========="
}

deploy_console() {
    log_info "========== CONSOLE 배포 시작 =========="

    # 1. 업로드 (node_modules / .env / uploads 제외)
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "mkdir -p ~/aiapp/apps/console ~/aiapp/data/console/uploads ~/aiapp/config/env ~/aiapp/data/logs/console"
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        --exclude='node_modules' \
        --exclude='.env' \
        --exclude='.git' \
        --exclude='public/uploads' \
        /Users/ghim/my_business/dksw_console/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/console/

    # 2. Docker 이미지 빌드 + raw docker run
    #    (docker-compose up -d 는 depends_on 사고 방지를 위해 사용하지 않음 — feedback_docker_compose_deps 참조)
    log_info "Docker 이미지 빌드 + 컨테이너 재기동..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
        set -e
        cd ~/aiapp/apps/console

        if [ ! -f ~/aiapp/config/env/console.env ]; then
            echo "[CONSOLE] ERROR: ~/aiapp/config/env/console.env 없음. 최초 배포는 .env 먼저 수동 생성."
            exit 1
        fi

        docker build -t aiapp_console:latest .
        docker stop aiapp_console 2>/dev/null || true
        docker rm -f aiapp_console 2>/dev/null || true
        docker run -d \
            --name aiapp_console \
            --restart unless-stopped \
            --network docker_aiapp_network \
            --env-file ~/aiapp/config/env/console.env \
            -v ~/aiapp/data/console/uploads:/app/public/uploads \
            -v ~/aiapp/data/logs/console:/logs \
            aiapp_console:latest

        # 3. 마이그레이션 (새 .sql 파일이 있으면 자동 적용, 이미 적용된 건 스킵)
        sleep 3
        echo "[CONSOLE] migrate..."
        docker exec aiapp_console node src/utils/migrate.js

        # 4. nginx reload (공식 dksw4.com/console/ 라우트)
        docker exec aiapp_nginx nginx -t
        docker exec aiapp_nginx nginx -s reload
        echo "[CONSOLE] nginx reloaded"
ENDSSH

    # 5. 로그 확인
    sleep 2
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_console 2>&1 | tail -10"

    log_info "========== CONSOLE 배포 완료 =========="
}

deploy_charge() {
    log_info "========== CHARGE 배포 시작 =========="

    # 1. 업로드
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/charge ~/aiapp/data/charge"
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        --exclude='node_modules' \
        --exclude='.env' \
        /Users/ghim/my_business/charge_server/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/charge/

    # 1-1. 정적 데이터 파일을 볼륨 마운트 경로에 동기화
    #      (/app/data 는 ~/aiapp/data/charge 로 bind mount 되어 이미지의 정적 파일이 가려짐.
    #       런타임 캐시인 evPrices.json/highwayStations.json 은 건드리지 않고 repo 추적 CSV 만 덮어쓴다.)
    log_info "정적 데이터(CSV) 볼륨 마운트 경로로 동기화..."
    scp -i $SSH_KEY /Users/ghim/my_business/charge_server/data/highway_rest_stops.csv \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/data/charge/highway_rest_stops.csv

    # 2. Docker 재시작
    log_info "Docker 컨테이너 재시작 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "cd ~/aiapp/docker && docker compose build --no-cache charge && { docker stop aiapp_charge 2>/dev/null; docker rm -f aiapp_charge 2>/dev/null; } ; docker compose up -d charge"

    # 3. 로그 확인
    log_info "시작 대기 중 (5초)..."
    sleep 5
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_charge 2>&1 | tail -5"

    log_info "========== CHARGE 배포 완료 =========="
}

deploy_homepage() {
    log_info "========== HOMEPAGE 배포 시작 =========="

    # 1. 업로드 (node_modules / .next / .env 제외)
    log_info "서버에 업로드 중..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p ~/aiapp/apps/dksw_homepage"
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        --exclude='node_modules' \
        --exclude='.next' \
        --exclude='.git' \
        --exclude='.env*' \
        --exclude='.DS_Store' \
        /Users/ghim/my_business/dksw_homepage/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/dksw_homepage/

    # 2. Docker 이미지 빌드 + raw docker run
    #    (docker-compose up -d 는 depends_on 사고 방지를 위해 사용하지 않음 — feedback_docker_compose_deps 참조)
    log_info "Docker 이미지 빌드 + 컨테이너 재기동..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
        set -e
        cd ~/aiapp/apps/dksw_homepage

        docker build -t aiapp/dksw_homepage:latest .
        docker stop aiapp_dksw_homepage 2>/dev/null || true
        docker rm -f aiapp_dksw_homepage 2>/dev/null || true
        docker run -d \
            --name aiapp_dksw_homepage \
            --restart unless-stopped \
            --network docker_aiapp_network \
            -e NODE_ENV=production \
            -e PORT=3100 \
            aiapp/dksw_homepage:latest

        sleep 2
        docker ps --filter "name=aiapp_dksw_homepage" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

        # nginx reload (dksw4.com / 라우트가 이 컨테이너로 프록시됨)
        docker exec aiapp_nginx nginx -t
        docker exec aiapp_nginx nginx -s reload
        echo "[HOMEPAGE] nginx reloaded"
ENDSSH

    # 3. 내부 헬스 체크
    log_info "내부 헬스 체크..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker exec aiapp_nginx wget -q -O- http://aiapp_dksw_homepage:3100/ | head -c 80 && echo" 2>/dev/null || log_warn "헬스 체크 실패 (컨테이너 기동 직후일 수 있음)"

    # 4. 로그 확인
    log_info "로그 확인:"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_dksw_homepage 2>&1 | tail -10"

    log_info "========== HOMEPAGE 배포 완료 =========="
}

deploy_cats() {
    log_info "========== CATS 배포 시작 =========="
    log_warn "주의: CATS 는 트레이딩 봇이라 blue/green 안 함 (중복 가동 위험). 단순 재시작."

    # 1. 코드 업로드 (Python — 빌드 X, rsync 만)
    log_info "코드 업로드..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "mkdir -p ~/aiapp/apps/cats ~/aiapp/data/logs/cats ~/aiapp/data/cats/results"
    rsync -avz --delete \
        -e "ssh -i $SSH_KEY" \
        --exclude='__pycache__' \
        --exclude='.venv' \
        --exclude='.env' \
        --exclude='.git' \
        --exclude='logs' \
        --exclude='data' \
        --exclude='results' \
        /Users/ghim/my_business/cats/ \
        $REMOTE_USER@$REMOTE_HOST:~/aiapp/apps/cats/

    # 2. Docker 재빌드 + 재시작 (5개 서비스: ws/coingecko/notices/bot/api)
    log_info "Docker 빌드 및 재시작..."
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
        set -e
        cd ~/aiapp/docker

        # build (의존 서비스만)
        docker compose build cats_ws cats_coingecko cats_notices cats_bot cats_api

        # force-recreate (DB 컨테이너 cats_timescale 는 안 건드림)
        docker compose up -d --no-deps --force-recreate \
            cats_ws cats_coingecko cats_notices cats_bot cats_api

        sleep 5
        echo "[CATS] 컨테이너 상태:"
        for svc in cats_ws cats_coingecko cats_notices cats_bot cats_api; do
            STATUS=$(docker inspect --format='{{.State.Status}}' aiapp_${svc} 2>/dev/null || echo "absent")
            echo "  ${svc}: ${STATUS}"
        done
ENDSSH

    # 3. 로그 확인
    log_info "최근 로그 (cats_ws):"
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker logs aiapp_cats_ws 2>&1 | tail -10" 2>/dev/null || log_warn "cats_ws 로그 없음"

    log_info "========== CATS 배포 완료 =========="
}

cleanup_images() {
    log_info "========== 안 쓰는 Docker 이미지 정리 =========="
    ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST \
        "docker image prune -f && docker images | grep -E 'aipf|aiif' | grep -v 'docker-' | awk '{print \$3}' | xargs -r docker rmi 2>/dev/null || true"
    log_info "정리 완료"
}

show_usage() {
    echo "사용법: $0 [aiif|aipf|kapt|charge|console|homepage|cats|all|cleanup]"
    echo ""
    echo "옵션:"
    echo "  aiif     - AIIF 서버만 배포"
    echo "  aipf     - AIPF 서버만 배포"
    echo "  kapt     - KAPT 서버만 배포"
    echo "  charge   - CHARGE 서버만 배포"
    echo "  console  - DKSW Console 배포"
    echo "  homepage - DKSW Homepage (dksw4.com) 배포"
    echo "  cats     - CATS 자동매매 봇 배포 (격자 통과 + 마이그레이션 후 사용)"
    echo "  all      - 모두 배포"
    echo "  cleanup  - 안 쓰는 Docker 이미지 정리"
    echo ""
    echo "예시:"
    echo "  $0 kapt"
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
    kapt)
        deploy_kapt
        ;;
    charge)
        deploy_charge
        ;;
    console)
        deploy_console
        ;;
    homepage)
        deploy_homepage
        ;;
    cats)
        deploy_cats
        ;;
    all)
        deploy_aiif
        echo ""
        deploy_aipf
        echo ""
        deploy_kapt
        echo ""
        deploy_charge
        echo ""
        deploy_console
        echo ""
        deploy_homepage
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
