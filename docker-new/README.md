# AI 플랫폼 Docker 배포 가이드 (Production-Ready)

## 📋 목차
1. [구조 개요](#구조-개요)
2. [서버 정보](#서버-정보)
3. [배포 전 준비](#배포-전-준비)
4. [배포 실행](#배포-실행)
5. [서비스 관리](#서비스-관리)
6. [설정 변경](#설정-변경)
7. [문제 해결](#문제-해결)

---

## 🏗️ 구조 개요

### 디렉토리 구조
```
/home/dksw/aiapp/
├── config/                 # 모든 설정 파일 (환경별 분리 가능)
│   ├── env/               # 환경 변수
│   │   ├── common.env     # 공통 설정
│   │   ├── db.env         # DB 설정
│   │   ├── aiif.env       # AIIF 환경변수
│   │   └── aipf.env       # AIPF 환경변수
│   │
│   ├── app/               # 애플리케이션 설정 (외부 주입)
│   │   ├── aiif/
│   │   │   ├── application-prod.yml
│   │   │   └── log4j2.xml
│   │   └── aipf/
│   │       ├── application-prod.yml
│   │       └── log4j2.xml
│   │
│   ├── nginx/             # Nginx 설정
│   │   ├── nginx.conf
│   │   └── conf.d/
│   │       └── aiapp.conf
│   │
│   ├── mysql/             # MySQL 초기화 스크립트
│   │   └── init.sql
│   │
│   └── redis/             # Redis 설정
│       └── redis.conf
│
├── docker/                # Docker 실행 파일
│   └── docker-compose.yml
│
├── apps/                  # 애플리케이션 바이너리
│   ├── aiif/
│   │   ├── Dockerfile
│   │   └── target/aiif-1.0.0.jar
│   └── aipf/
│       ├── Dockerfile
│       └── target/aipf-1.0.0.jar
│
└── data/                  # 영구 데이터 (백업 대상)
    ├── mysql/            # MySQL 데이터
    ├── redis/            # Redis 데이터
    └── logs/             # 애플리케이션 로그
        ├── aiif/
        └── aipf/
```

### 핵심 개념

✅ **설정 완전 분리**: JAR 파일은 순수 로직만 포함. 모든 설정은 외부에서 주입

✅ **환경별 전환 용이**: `config/env/` 디렉토리만 교체하면 dev/stage/prod 전환 가능

✅ **운영 안정성**: 설정 변경 시 재빌드 불필요. 컨테이너 재시작만으로 반영

✅ **로그 관리**: 컨테이너 외부에 로그 저장. 컨테이너 재시작해도 로그 유지

---

## 🖥️ 서버 정보

- **SSH 호스트**: 223.130.151.39
- **SSH 포트**: 22
- **서버 계정**: dksw / dksw.123
- **루트 계정**: root / aime.123
- **SSH 키**: `~/.ssh/my_business_deploy`
- **SSH 키 비밀번호**: `MyBusiness@2026!`

---

## 📦 배포 전 준비

### 1. 로컬에서 JAR 빌드

```bash
cd /Users/ghim/my_business

# AIIF 빌드
cd aiif
mvn clean package -DskipTests

# AIPF 빌드
cd ../aipf
mvn clean package -DskipTests

cd ..
```

### 2. SSH 키 설정 (선택사항)

SSH 키 인증이 안 되면 비밀번호로 접속합니다. 키 인증을 원하면:

```bash
# 공개키 확인
cat ~/.ssh/my_business_deploy.pub

# 서버 접속
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

# 공개키 등록
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "여기에_공개키_붙여넣기" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit

# 테스트
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39
```

---

## 🚀 배포 실행

### 자동 배포 (권장)

```bash
cd /Users/ghim/my_business/docker-new/scripts
chmod +x deploy.sh
./deploy.sh
```

스크립트가 자동으로:
1. JAR 파일 존재 확인
2. 서버 디렉토리 생성
3. 모든 설정 파일 전송
4. 기존 컨테이너 중지
5. 새 컨테이너 빌드 및 실행

### 수동 배포

#### 1. 서버에 디렉토리 생성

```bash
ssh dksw@223.130.151.39
mkdir -p /home/dksw/aiapp/{config/{env,app/{aiif,aipf},nginx/conf.d,mysql,redis},docker,data/{mysql,redis,logs/{aiif,aipf}},apps/{aiif/target,aipf/target}}
exit
```

#### 2. 파일 전송

```bash
cd /Users/ghim/my_business/docker-new

# 설정 파일
scp -r config/env dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/app dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/nginx dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/mysql dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/redis dksw@223.130.151.39:/home/dksw/aiapp/config/

# Docker 파일
scp docker/docker-compose.yml dksw@223.130.151.39:/home/dksw/aiapp/docker/

# 애플리케이션 파일
scp apps/aiif/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/apps/aiif/
scp apps/aiif/target/aiif-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/apps/aiif/target/

scp apps/aipf/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/apps/aipf/
scp apps/aipf/target/aipf-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/apps/aipf/target/
```

#### 3. 서버에서 실행

```bash
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/docker

# 기존 컨테이너 중지 (있으면)
docker-compose down

# 컨테이너 빌드 및 실행
docker-compose up -d --build

# 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

---

## 🛠️ 서비스 관리

### 기본 명령어

```bash
# 서버 접속
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/docker

# 전체 상태 확인
docker-compose ps

# 로그 확인 (전체)
docker-compose logs -f

# 특정 서비스 로그
docker-compose logs -f aiif
docker-compose logs -f aipf
docker-compose logs -f mysql

# 서비스 재시작
docker-compose restart aiif
docker-compose restart aipf

# 전체 재시작
docker-compose restart

# 서비스 중지
docker-compose stop

# 서비스 시작
docker-compose start

# 컨테이너 제거 (데이터는 유지)
docker-compose down

# 컨테이너 + 볼륨 제거 (주의!)
docker-compose down -v
```

### 서비스 URL

- **AIIF API**: http://223.130.151.39:1024
- **AIPF API**: http://223.130.151.39:2022
- **Nginx**: http://223.130.151.39:80
- **MySQL**: 223.130.151.39:3306
- **Redis**: 223.130.151.39:6379

---

## ⚙️ 설정 변경

### 환경 변수 변경

```bash
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/config/env

# 원하는 파일 수정
vi aiif.env
vi aipf.env

# 재시작
cd /home/dksw/aiapp/docker
docker-compose restart aiif
docker-compose restart aipf
```

### 애플리케이션 설정 변경

```bash
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/config/app

# AIIF 설정 변경
vi aiif/application-prod.yml

# 재시작
cd /home/dksw/aiapp/docker
docker-compose restart aiif
```

### 로그 레벨 변경

```bash
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/config/app

# log4j2.xml 수정
vi aiif/log4j2.xml

# <Root level="INFO"> → <Root level="DEBUG">

# 재시작
cd /home/dksw/aiapp/docker
docker-compose restart aiif
```

**재빌드 불필요!** 설정만 변경하고 재시작하면 바로 반영됨.

### Nginx 설정 변경

```bash
ssh dksw@223.130.151.39
cd /home/dksw/aiapp/config/nginx

# 설정 수정
vi conf.d/aiapp.conf

# 재시작
cd /home/dksw/aiapp/docker
docker-compose restart nginx
```

---

## 🐛 문제 해결

### 컨테이너가 시작 안 됨

```bash
# 로그 확인
docker-compose logs

# 특정 서비스만
docker-compose logs aiif

# 컨테이너 상세 정보
docker inspect aiapp_aiif
```

### MySQL 연결 실패

```bash
# MySQL 헬스체크
docker-compose ps mysql

# MySQL 로그
docker-compose logs mysql

# MySQL 접속 테스트
docker-compose exec mysql mysql -u root -paime.123
```

### Redis 연결 실패

```bash
# Redis 상태
docker-compose ps redis

# Redis 접속 테스트
docker-compose exec redis redis-cli ping
```

### 로그 확인

```bash
# 컨테이너 로그
docker-compose logs -f aiif

# 파일 시스템 로그
cd /home/dksw/aiapp/data/logs/aiif
tail -f aiif.log
tail -f aiif-error.log
```

### 디스크 공간 부족

```bash
# 디스크 사용량
df -h

# Docker 정리
docker system prune -a
docker volume prune
```

---

## 🔄 업데이트 배포

```bash
# 1. 로컬에서 빌드
cd /Users/ghim/my_business
cd aiif && mvn clean package -DskipTests
cd ../aipf && mvn clean package -DskipTests

# 2. 배포 스크립트 실행
cd ../docker-new/scripts
./deploy.sh
```

---

## 🔒 보안 권장사항

### 1. 방화벽 설정

```bash
ssh root@223.130.151.39

firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=1024/tcp
firewall-cmd --permanent --add-port=2022/tcp
firewall-cmd --reload
```

### 2. 비밀번호 변경

```bash
# 서버 계정 비밀번호
ssh dksw@223.130.151.39
passwd

# DB 비밀번호는 config/env/db.env 수정
```

### 3. 정기 업데이트

```bash
# 시스템 업데이트
yum update -y

# Docker 이미지 업데이트
docker-compose pull
docker-compose up -d
```

---

## 📞 지원

문제 발생 시:

```bash
# 전체 시스템 상태
docker-compose ps
docker-compose logs --tail=100

# 시스템 리소스
free -h
df -h
docker stats
```

---

## 핵심 개념 요약

1. **설정은 코드 밖에**: application.yml, log4j2.xml 모두 외부 주입
2. **환경 전환 용이**: config/env만 바꾸면 dev/prod 전환
3. **재빌드 불필요**: 설정 변경 후 컨테이너 재시작만
4. **로그 영구 보관**: 컨테이너 삭제해도 로그 유지
5. **운영 안정성**: 설정 오류 시 롤백 즉시 가능

이 구조는 Kubernetes 전환 시에도 그대로 사용 가능합니다.
