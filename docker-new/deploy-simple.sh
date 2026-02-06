#!/bin/bash
set -e

echo "============================================"
echo "AI Platform 배포 스크립트 (Simple Version)"
echo "============================================"
echo ""
echo "이 스크립트는 scp 명령으로 파일을 전송합니다."
echo "비밀번호는 각 전송마다 입력해야 합니다: dksw.123"
echo ""
read -p "계속하려면 Enter를 누르세요..."

SERVER="dksw@223.130.151.39"
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

echo ""
echo "1️⃣ 압축 파일 생성 중..."
cd "$BASE_DIR"
tar -czf /tmp/aiapp-deploy.tar.gz config/ docker/ apps/
echo "✅ 압축 완료: /tmp/aiapp-deploy.tar.gz"

echo ""
echo "2️⃣ 서버에 파일 전송 중..."
echo "(비밀번호 입력: dksw.123)"
scp /tmp/aiapp-deploy.tar.gz ${SERVER}:/tmp/

echo ""
echo "3️⃣ 서버에서 명령 실행..."
echo "(비밀번호 입력: dksw.123)"
ssh ${SERVER} << 'ENDSSH'
set -e

echo "기존 컨테이너 중지..."
cd /home/dksw/aiapp/docker 2>/dev/null && docker-compose down -v || echo "No containers"

echo "기존 디렉토리 백업..."
cd /home/dksw
if [ -d "aiapp" ]; then
    mv aiapp aiapp.backup.$(date +%Y%m%d_%H%M%S) || rm -rf aiapp
fi

echo "새 디렉토리 생성..."
mkdir -p aiapp
cd aiapp

echo "압축 해제..."
tar -xzf /tmp/aiapp-deploy.tar.gz
rm /tmp/aiapp-deploy.tar.gz

echo "데이터 디렉토리 생성..."
mkdir -p data/{mysql,redis,logs/{aiif,aipf}}

echo "Docker Compose 실행..."
cd docker
docker-compose up -d --build

echo ""
echo "✅ 배포 완료!"
echo ""
echo "컨테이너 상태:"
docker-compose ps

echo ""
echo "접속 정보:"
echo "  - AIIF: http://223.130.151.39:1024"
echo "  - AIPF: http://223.130.151.39:2022"
echo "  - Nginx: http://223.130.151.39:80"
ENDSSH

echo ""
echo "============================================"
echo "✅ 배포 완료!"
echo "============================================"
echo ""
echo "로그 확인: ssh dksw@223.130.151.39 'cd /home/dksw/aiapp/docker && docker-compose logs -f'"
