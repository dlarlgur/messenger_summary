# AI 플랫폼 Docker 배포 가이드

## 📋 목차
1. [서버 정보](#서버-정보)
2. [배포 전 준비사항](#배포-전-준비사항)
3. [서버 초기 설정](#서버-초기-설정)
4. [애플리케이션 배포](#애플리케이션-배포)
5. [SSL 인증서 설정](#ssl-인증서-설정)
6. [서비스 관리](#서비스-관리)
7. [문제 해결](#문제-해결)

## 🖥️ 서버 정보

- **SSH 호스트**: 223.130.151.39
- **SSH 포트**: 22
- **서버 사용자 계정**: dksw / dksw.123
- **서버 루트 계정**: root / aime.123
- **SSH 키 파일**: `~/.ssh/my_business_deploy`
- **SSH 키 비밀번호**: `MyBusiness@2026!`

## 📦 배포 전 준비사항

### 1. SSH 키 등록

서버에 SSH 키를 수동으로 등록해야 합니다:

```bash
# 1. 로컬의 공개 키 확인
cat ~/.ssh/my_business_deploy.pub

# 2. 서버에 SSH로 접속
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

# 3. 서버에서 authorized_keys에 공개 키 추가
mkdir -p ~/.ssh
chmod 700 ~/.ssh
vi ~/.ssh/authorized_keys
# 위에서 복사한 공개 키를 붙여넣기
chmod 600 ~/.ssh/authorized_keys
exit

# 4. SSH 키로 접속 테스트
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39
```

## 🔧 서버 초기 설정

### 1. Docker 및 Docker Compose 설치

서버에 root 계정으로 접속하여 Docker를 설치합니다:

```bash
# root로 접속
ssh root@223.130.151.39
# 비밀번호: aime.123

# 설정 스크립트 업로드 후 실행 (또는 수동으로 명령 실행)
# 스크립트 내용은 server-setup.sh 참조
yum update -y
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker
usermod -aG docker dksw

# Docker Compose 설치
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# 확인
docker --version
docker-compose --version

# 작업 디렉토리 생성
mkdir -p /home/dksw/aiapp
chown -R dksw:dksw /home/dksw/aiapp

exit
```

### 2. dksw 사용자 재로그인

Docker 그룹 추가가 적용되도록 재로그인합니다:

```bash
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39
docker ps  # 권한 확인
```

## 🚀 애플리케이션 배포

### 자동 배포 (권장)

로컬에서 배포 스크립트를 실행합니다:

```bash
cd /Users/ghim/my_business
chmod +x docker/deploy.sh
./docker/deploy.sh
```

### 수동 배포

#### 1. 파일 전송

```bash
cd /Users/ghim/my_business

# 서버 디렉토리 생성
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39 "mkdir -p /home/dksw/aiapp/{docker,aiif/target,aipf/target}"

# Docker 설정 파일 전송
scp -i ~/.ssh/my_business_deploy -r docker/.env dksw@223.130.151.39:/home/dksw/aiapp/docker/
scp -i ~/.ssh/my_business_deploy -r docker/docker-compose.yml dksw@223.130.151.39:/home/dksw/aiapp/docker/
scp -i ~/.ssh/my_business_deploy -r docker/nginx dksw@223.130.151.39:/home/dksw/aiapp/docker/
scp -i ~/.ssh/my_business_deploy -r docker/mysql-init dksw@223.130.151.39:/home/dksw/aiapp/docker/

# aiif 파일 전송
scp -i ~/.ssh/my_business_deploy aiif/target/aiif-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/aiif/target/
scp -i ~/.ssh/my_business_deploy aiif/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/aiif/

# aipf 파일 전송
scp -i ~/.ssh/my_business_deploy aipf/target/aipf-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/aipf/target/
scp -i ~/.ssh/my_business_deploy aipf/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/aipf/
```

#### 2. Docker Compose 실행

```bash
# 서버에 접속
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39

cd /home/dksw/aiapp/docker

# .env 파일 확인 및 필요시 수정
vi .env

# Docker Compose 실행
docker-compose up -d --build

# 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

## 🔐 SSL 인증서 설정

### Let's Encrypt 무료 SSL 인증서 발급

서버에서 실행:

```bash
cd /home/dksw/aiapp/docker

# SSL 설정 스크립트 실행
chmod +x ssl-setup.sh
./ssl-setup.sh

# 도메인과 이메일 입력 프롬프트가 나타납니다
# 예: example.com, admin@example.com
```

## 🛠️ 서비스 관리

### 기본 명령어

```bash
# 서버 접속
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39
cd /home/dksw/aiapp/docker

# 모든 컨테이너 상태 확인
docker-compose ps

# 특정 서비스 로그 확인
docker-compose logs -f aiif
docker-compose logs -f aipf
docker-compose logs -f mysql
docker-compose logs -f redis
docker-compose logs -f nginx

# 서비스 재시작
docker-compose restart aiif
docker-compose restart aipf

# 모든 서비스 재시작
docker-compose restart

# 서비스 중지
docker-compose stop

# 서비스 시작
docker-compose start

# 컨테이너 제거 (데이터는 유지)
docker-compose down

# 컨테이너와 볼륨 모두 제거 (주의!)
docker-compose down -v
```

### 데이터베이스 접속

```bash
# MySQL 컨테이너에 접속
docker-compose exec mysql mysql -u root -p
# 비밀번호: aime.123

# 데이터베이스 확인
USE aidb;
SHOW TABLES;
```

### Redis 접속

```bash
# Redis CLI 접속
docker-compose exec redis redis-cli

# 키 확인
KEYS *
```

## 📍 서비스 접속 정보

- **aiif API**: http://223.130.151.39:1024 (내부: 1309)
- **aipf API**: http://223.130.151.39:2022 (내부: 8081)
- **Nginx (HTTP)**: http://223.130.151.39:80
- **Nginx (HTTPS)**: https://your-domain:443
- **MySQL**: 223.130.151.39:3306
- **Redis**: 223.130.151.39:6379

### API 엔드포인트

#### AIIF
- `/aiif/api/v1/chat/ask` - AI 질문
- `/aiif/api/v1/chat/stream` - 스트리밍 응답
- `/aiif/api/v1/product/search` - 상품 검색

#### AIPF
- `/api/v1/auth/login` - 로그인
- `/api/v1/auth/signup` - 회원가입
- `/api/v1/chat/rooms` - 채팅방 목록
- `/api/v1/chat/ask` - AI 대화

## 🐛 문제 해결

### 컨테이너가 시작되지 않는 경우

```bash
# 로그 확인
docker-compose logs

# 특정 서비스 로그
docker-compose logs aiif
docker-compose logs aipf

# 컨테이너 재시작
docker-compose restart
```

### MySQL 연결 오류

```bash
# MySQL 컨테이너 상태 확인
docker-compose ps mysql

# MySQL 로그 확인
docker-compose logs mysql

# MySQL 헬스체크 확인
docker-compose exec mysql mysqladmin ping -h localhost -u root -paime.123
```

### Redis 연결 오류

```bash
# Redis 상태 확인
docker-compose ps redis

# Redis 로그 확인
docker-compose logs redis

# Redis 연결 테스트
docker-compose exec redis redis-cli ping
```

### 포트 충돌

```bash
# 포트 사용 확인
netstat -tulpn | grep :1024
netstat -tulpn | grep :2022
netstat -tulpn | grep :3306
netstat -tulpn | grep :6379

# 충돌 시 .env 파일에서 포트 변경
vi .env
docker-compose down
docker-compose up -d
```

### 디스크 공간 부족

```bash
# 디스크 사용량 확인
df -h

# 사용하지 않는 Docker 이미지 제거
docker image prune -a

# 사용하지 않는 볼륨 제거
docker volume prune

# 사용하지 않는 컨테이너 제거
docker container prune
```

### 애플리케이션 로그 확인

```bash
# 실시간 로그 모니터링
docker-compose logs -f --tail=100

# 특정 서비스만
docker-compose logs -f aiif
docker-compose logs -f aipf

# 로그 파일 직접 확인 (컨테이너 내부)
docker-compose exec aiif ls -la /home/dksw/aiif/logs
docker-compose exec aipf ls -la /home/dksw/aipf/logs
```

## 🔄 업데이트 및 재배포

```bash
# 로컬에서 애플리케이션 재빌드
cd /Users/ghim/my_business
cd aiif && mvn clean package -DskipTests
cd ../aipf && mvn clean package -DskipTests

# 배포 스크립트 실행
cd ..
./docker/deploy.sh
```

## 📝 환경 변수 설정

`.env` 파일을 수정하여 설정을 변경할 수 있습니다:

```bash
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39
cd /home/dksw/aiapp/docker
vi .env

# 변경 후 재시작
docker-compose down
docker-compose up -d
```

## 🔒 보안 권장사항

1. **SSH 비밀번호 변경**
   ```bash
   passwd dksw
   ```

2. **방화벽 설정**
   ```bash
   # firewalld 설치 및 시작
   yum install -y firewalld
   systemctl start firewalld
   systemctl enable firewalld

   # 필요한 포트만 개방
   firewall-cmd --permanent --add-port=22/tcp
   firewall-cmd --permanent --add-port=80/tcp
   firewall-cmd --permanent --add-port=443/tcp
   firewall-cmd --permanent --add-port=1024/tcp
   firewall-cmd --permanent --add-port=2022/tcp
   firewall-cmd --reload
   ```

3. **정기적인 시스템 업데이트**
   ```bash
   yum update -y
   ```

4. **Docker 이미지 정기 업데이트**
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

## 📞 지원

문제가 발생하면 로그를 확인하고 필요시 개발팀에 문의하세요.

```bash
# 전체 시스템 상태 확인
docker-compose ps
docker-compose logs --tail=100

# 시스템 리소스 확인
free -h
df -h
docker stats
```
