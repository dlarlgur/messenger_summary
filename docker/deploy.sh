#!/bin/bash

# 배포 스크립트
# 로컬에서 실행하여 서버로 파일을 전송하고 Docker를 실행합니다

set -e

# 변수 설정
SERVER_USER="dksw"
SERVER_HOST="223.130.151.39"
SERVER_DIR="/home/dksw/aiapp"
SSH_KEY="~/.ssh/my_business_deploy"

echo "=== 배포 시작 ==="

# 서버 디렉토리 생성
echo "서버 디렉토리 생성 중..."
ssh -i ${SSH_KEY} ${SERVER_USER}@${SERVER_HOST} "mkdir -p ${SERVER_DIR}/{docker,aiif/target,aipf/target}"

# Docker 설정 파일 전송
echo "Docker 설정 파일 전송 중..."
scp -i ${SSH_KEY} -r docker/.env ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/docker/
scp -i ${SSH_KEY} -r docker/docker-compose.yml ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/docker/
scp -i ${SSH_KEY} -r docker/nginx ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/docker/
scp -i ${SSH_KEY} -r docker/mysql-init ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/docker/

# JAR 파일 및 Dockerfile 전송
echo "aiif 파일 전송 중..."
scp -i ${SSH_KEY} aiif/target/aiif-1.0.0.jar ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/aiif/target/
scp -i ${SSH_KEY} aiif/Dockerfile ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/aiif/

echo "aipf 파일 전송 중..."
scp -i ${SSH_KEY} aipf/target/aipf-1.0.0.jar ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/aipf/target/
scp -i ${SSH_KEY} aipf/Dockerfile ${SERVER_USER}@${SERVER_HOST}:${SERVER_DIR}/aipf/

echo "파일 전송 완료!"

# 서버에서 Docker Compose 실행
echo "서버에서 Docker Compose 실행 중..."
ssh -i ${SSH_KEY} ${SERVER_USER}@${SERVER_HOST} << 'ENDSSH'
cd /home/dksw/aiapp/docker

# 기존 컨테이너 중지 및 제거
echo "기존 컨테이너 중지 및 제거 중..."
docker-compose down || true

# 이미지 빌드 및 컨테이너 시작
echo "Docker 이미지 빌드 및 컨테이너 시작 중..."
docker-compose up -d --build

# 컨테이너 상태 확인
echo "컨테이너 상태 확인 중..."
docker-compose ps

echo "로그 확인 (10초)..."
sleep 10
docker-compose logs --tail=50

ENDSSH

echo "=== 배포 완료 ==="
echo "서비스 접속 정보:"
echo "  - aiif: http://223.130.151.39:1024"
echo "  - aipf: http://223.130.151.39:2022"
echo "  - nginx (HTTP): http://223.130.151.39"
echo ""
echo "서버 로그 확인: ssh -i ${SSH_KEY} ${SERVER_USER}@${SERVER_HOST} 'cd /home/dksw/aiapp/docker && docker-compose logs -f'"
