# Nginx + Certbot SSL 설정 가이드

## 1. HTML 파일 업로드

```bash
# 서버에 접속
ssh user@your-server

# HTML 파일을 웹 루트에 복사
sudo cp privacy.html /var/www/html/privacy.html
sudo chown www-data:www-data /var/www/html/privacy.html
sudo chmod 644 /var/www/html/privacy.html
```

## 2. Nginx 설정

```bash
# 설정 파일 생성
sudo nano /etc/nginx/sites-available/privacy

# 위의 nginx_privacy.conf 내용을 복사하여 붙여넣기
# "내도메인.com"을 실제 도메인으로 변경

# 심볼릭 링크 생성
sudo ln -s /etc/nginx/sites-available/privacy /etc/nginx/sites-enabled/

# Nginx 설정 테스트
sudo nginx -t

# Nginx 재시작
sudo systemctl restart nginx
```

## 3. Certbot으로 SSL 인증서 발급

### 3.1 Certbot 설치

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install certbot python3-certbot-nginx

# CentOS/RHEL
sudo yum install certbot python3-certbot-nginx
```

### 3.2 SSL 인증서 발급

```bash
# 자동으로 Nginx 설정까지 완료
sudo certbot --nginx -d 내도메인.com -d www.내도메인.com

# 또는 수동으로 인증서만 발급
sudo certbot certonly --nginx -d 내도메인.com -d www.내도메인.com
```

### 3.3 인증서 자동 갱신 설정

```bash
# Certbot이 자동으로 갱신 스크립트를 등록함
# 테스트 실행
sudo certbot renew --dry-run

# cron 작업 확인 (보통 자동으로 설정됨)
sudo systemctl status certbot.timer
```

## 4. Nginx HTTPS 설정 활성화

Certbot이 자동으로 설정하지만, 수동으로 하려면:

```bash
# nginx_privacy.conf의 HTTPS 블록 주석 해제
sudo nano /etc/nginx/sites-available/privacy

# HTTP에서 HTTPS로 리다이렉트 활성화
# return 301 https://$server_name$request_uri; 주석 해제

# Nginx 재시작
sudo nginx -t
sudo systemctl restart nginx
```

## 5. 방화벽 설정 (필요시)

```bash
# UFW 사용 시
sudo ufw allow 'Nginx Full'
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# firewalld 사용 시
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## 6. 확인

```bash
# HTTP 접속 확인
curl http://내도메인.com/privacy

# HTTPS 접속 확인 (SSL 발급 후)
curl https://내도메인.com/privacy

# 브라우저에서 확인
# http://내도메인.com/privacy
# https://내도메인.com/privacy
```

## 주의사항

1. **도메인 DNS 설정**: 도메인의 A 레코드가 서버 IP를 가리키도록 설정되어 있어야 합니다.
2. **포트 80, 443 열기**: Certbot이 인증을 위해 포트 80에 접근해야 합니다.
3. **도메인 변경**: 모든 설정 파일에서 "내도메인.com"을 실제 도메인으로 변경해야 합니다.
