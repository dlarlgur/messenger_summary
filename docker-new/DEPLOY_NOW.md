# 🚀 지금 바로 배포하기

압축 파일로 한 번에 전송하는 방식입니다.

## 방법 1: 압축 파일 사용 (권장)

### 1단계: 압축 파일 생성 (이미 완료됨)
```bash
# 로컬에서
cd /Users/ghim/my_business/docker-new
tar -czf /tmp/aiapp-deploy.tar.gz config/ docker/ apps/
```

### 2단계: 서버 준비 및 파일 전송
```bash
# 터미널 1: 서버 접속
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

# 기존 컨테이너 중지
cd /home/dksw/aiapp/docker 2>/dev/null && docker-compose down -v || echo "OK"

# 디렉토리 준비
cd /home/dksw
rm -rf aiapp
mkdir -p aiapp
cd aiapp

# 로그아웃하지 말고 그대로 두세요!
```

```bash
# 터미널 2: 로컬에서 파일 전송
scp /tmp/aiapp-deploy.tar.gz dksw@223.130.151.39:/home/dksw/aiapp/
# 비밀번호: dksw.123
```

### 3단계: 서버에서 압축 해제 및 실행
```bash
# 터미널 1에서 계속
cd /home/dksw/aiapp
tar -xzf aiapp-deploy.tar.gz
rm aiapp-deploy.tar.gz

# 데이터 디렉토리 생성
mkdir -p data/{mysql,redis,logs/{aiif,aipf}}

# Docker 실행
cd docker
docker-compose up -d --build

# 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

---

## 방법 2: 명령어로 직접 전송

### 1단계: 서버 준비
```bash
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

cd /home/dksw/aiapp/docker 2>/dev/null && docker-compose down -v || echo "OK"
mkdir -p /home/dksw/aiapp/{config/{env,app/{aiif,aipf},nginx/conf.d,mysql,redis},docker,data/{mysql,redis,logs/{aiif,aipf}},apps/{aiif/target,aipf/target}}
exit
```

### 2단계: 파일 전송 (로컬)
```bash
cd /Users/ghim/my_business/docker-new

# 각 명령마다 비밀번호 입력: dksw.123
scp -r config/env dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/app dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/nginx dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/mysql dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/redis dksw@223.130.151.39:/home/dksw/aiapp/config/
scp docker/docker-compose.yml dksw@223.130.151.39:/home/dksw/aiapp/docker/
scp apps/aiif/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/apps/aiif/
scp apps/aiif/target/aiif-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/apps/aiif/target/
scp apps/aipf/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/apps/aipf/
scp apps/aipf/target/aipf-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/apps/aipf/target/
```

### 3단계: Docker 실행
```bash
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

cd /home/dksw/aiapp/docker
docker-compose up -d --build
docker-compose ps
docker-compose logs -f
```

---

## 완료 확인

### 서비스 접속 테스트
```bash
# AIIF
curl http://223.130.151.39:1024/actuator/health

# AIPF
curl http://223.130.151.39:2022/actuator/health

# Nginx
curl http://223.130.151.39/health
```

### 로그 확인
```bash
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/docker

# 실시간 로그
docker-compose logs -f

# 특정 서비스만
docker-compose logs -f aiif
docker-compose logs -f aipf

# 파일 시스템 로그
tail -f ../data/logs/aiif/aiif.log
tail -f ../data/logs/aipf/aipf.log
```

---

## 서비스 URL

배포 완료 후:
- **AIIF API**: http://223.130.151.39:1024
- **AIPF API**: http://223.130.151.39:2022
- **Nginx**: http://223.130.151.39:80
- **MySQL**: 223.130.151.39:3306
- **Redis**: 223.130.151.39:6379

---

## 문제 해결

### 컨테이너가 안 올라오면
```bash
cd /home/dksw/aiapp/docker
docker-compose ps
docker-compose logs mysql
docker-compose logs redis
docker-compose logs aiif
docker-compose logs aipf
```

### MySQL 초기화 문제
```bash
# MySQL 볼륨 삭제 후 재시작
cd /home/dksw/aiapp/docker
docker-compose down -v
rm -rf ../data/mysql/*
docker-compose up -d --build
```

### 전체 재배포
```bash
cd /home/dksw/aiapp/docker
docker-compose down -v
cd ..
rm -rf aiapp
# 다시 1단계부터 시작
```
