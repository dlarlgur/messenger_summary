#!/bin/bash

# 서버 초기 설정 스크립트 (Ubuntu용)
# 서버에서 root 권한으로 실행하세요

set -e

echo "=== Docker 및 Docker Compose 설치 시작 (Ubuntu) ==="

# 시스템 업데이트
echo "시스템 업데이트 중..."
apt-get update -y
apt-get upgrade -y

# Docker 설치에 필요한 패키지 설치
echo "필요한 패키지 설치 중..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Docker GPG 키 추가
echo "Docker GPG 키 추가 중..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Docker 저장소 추가
echo "Docker 저장소 추가 중..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 패키지 목록 업데이트
apt-get update -y

# Docker 설치
echo "Docker 설치 중..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 서비스 시작 및 자동 시작 설정
echo "Docker 서비스 시작 중..."
systemctl start docker
systemctl enable docker

# dksw 사용자를 docker 그룹에 추가
echo "dksw 사용자를 docker 그룹에 추가 중..."
usermod -aG docker dksw

# Docker Compose 설치 (standalone)
echo "Docker Compose 설치 중..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Docker Compose 심볼릭 링크 생성
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 작업 디렉토리 생성
echo "작업 디렉토리 생성 중..."
mkdir -p /home/dksw/aiapp
chown -R dksw:dksw /home/dksw/aiapp

# 설치 확인
echo "=== 설치 확인 ==="
docker --version
docker-compose --version
docker compose version

echo "=== Docker 설치 완료 ==="
echo "주의: dksw 사용자가 docker 그룹에 추가되었습니다."
echo "변경사항을 적용하려면 dksw 사용자로 재로그인하세요."
