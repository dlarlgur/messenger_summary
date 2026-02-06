#!/bin/bash

# SSL 인증서 설정 스크립트
# 서버에서 실행하세요

set -e

# 도메인과 이메일을 입력받습니다
read -p "도메인 이름을 입력하세요 (예: example.com): " DOMAIN
read -p "이메일 주소를 입력하세요: " EMAIL

echo "=== SSL 인증서 설정 시작 ==="
echo "도메인: $DOMAIN"
echo "이메일: $EMAIL"

cd /home/dksw/aiapp/docker

# certbot 디렉토리 생성
mkdir -p certbot/conf certbot/www

# Nginx 설정 파일에서 도메인 업데이트
echo "Nginx 설정 파일 업데이트 중..."
sed -i "s/your-domain/${DOMAIN}/g" nginx/conf.d/default.conf

# 임시로 자체 서명 인증서 생성 (Let's Encrypt 인증서를 받기 전까지 사용)
echo "임시 자체 서명 인증서 생성 중..."
mkdir -p certbot/conf/live/${DOMAIN}
openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
    -keyout certbot/conf/live/${DOMAIN}/privkey.pem \
    -out certbot/conf/live/${DOMAIN}/fullchain.pem \
    -subj "/CN=${DOMAIN}"

# Nginx 재시작
echo "Nginx 재시작 중..."
docker-compose restart nginx

# Let's Encrypt 인증서 발급
echo "Let's Encrypt 인증서 발급 중..."
docker-compose run --rm certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email ${EMAIL} \
    --agree-tos \
    --no-eff-email \
    -d ${DOMAIN}

# Nginx 다시 재시작하여 실제 인증서 적용
echo "Nginx 재시작 (실제 인증서 적용)..."
docker-compose restart nginx

echo "=== SSL 인증서 설정 완료 ==="
echo "HTTPS 접속: https://${DOMAIN}"
echo ""
echo "인증서는 자동으로 갱신됩니다."
