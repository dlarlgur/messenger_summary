# AI 플랫폼 운영 가이드

## 📍 현재 배포 상태

### 서버 정보
- **IP**: 223.130.151.39
- **계정**: dksw / dksw.123
- **SSH 키**: `~/.ssh/my_business_deploy` (passphrase: `MyBusiness@2026!`)

### 서비스 URL
- **HTTPS API (권장)**: https://223.130.151.39/api/
- **HTTPS AIIF**: https://223.130.151.39/aiif/
- **네이버 OAuth Redirect**: https://223.130.151.39/api/v1/auth/naver/callback

### 컨테이너 구성
```
aiapp_mysql   → MySQL 8.0 (포트 3306)
aiapp_redis   → Redis 7 (포트 6379)
aiapp_aiif    → AIIF 애플리케이션 (내부 1309)
aiapp_aipf    → AIPF 애플리케이션 (내부 8081)
aiapp_nginx   → Nginx (포트 80, 443)
```

---

## 🔧 서버 접속

### SSH 접속
```bash
# SSH 키 agent에 추가 (처음 1번만)
ssh-add ~/.ssh/my_business_deploy
# passphrase 입력: MyBusiness@2026!

# 서버 접속
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39
```

### Docker 명령어 (서버에서)
```bash
cd /home/dksw/aiapp/docker

# 컨테이너 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f

# 특정 서비스 로그
docker compose logs -f aiif
docker compose logs -f aipf
docker compose logs -f mysql
```

---

## 📂 디렉토리 구조

```
/home/dksw/aiapp/
├── config/                    # 모든 설정 파일
│   ├── env/                  # 환경 변수
│   │   ├── common.env        # 공통 설정 (타임존 등)
│   │   ├── db.env           # MySQL 비밀번호
│   │   ├── aiif.env         # AIIF 환경변수 (DB URL 등)
│   │   └── aipf.env         # AIPF 환경변수 (JWT secret 등)
│   │
│   ├── app/                  # 애플리케이션 설정 (중요!)
│   │   ├── aiif/
│   │   │   ├── application-prod.yml    # AIIF 설정
│   │   │   └── log4j2.xml             # AIIF 로그 설정
│   │   └── aipf/
│   │       ├── application-prod.yml    # AIPF 설정
│   │       └── log4j2.xml             # AIPF 로그 설정
│   │
│   ├── nginx/
│   │   ├── nginx.conf
│   │   ├── conf.d/aiapp.conf
│   │   └── ssl/              # SSL 인증서
│   │
│   ├── mysql/init.sql
│   └── redis/redis.conf
│
├── docker/
│   └── docker-compose.yml
│
├── apps/                      # JAR 파일 (빌드 결과물)
│   ├── aiif/
│   │   ├── Dockerfile
│   │   └── target/aiif-1.0.0.jar
│   └── aipf/
│       ├── Dockerfile
│       └── target/aipf-1.0.0.jar
│
└── data/                      # 영구 데이터 (백업 필수!)
    ├── mysql/                # DB 데이터
    ├── redis/                # Redis 데이터
    └── logs/                 # 애플리케이션 로그
        ├── aiif/
        │   ├── aiif_debug.log         # 일반 로그
        │   └── aiif_trace.log         # API 요청/응답 추적 로그
        └── aipf/
            ├── aipf_debug.log         # 일반 로그
            └── aipf_trace.log         # API 요청/응답 추적 로그
```

---

## 📝 로그 확인

### 1. Docker 로그 (실시간)
```bash
cd /home/dksw/aiapp/docker

# 전체 로그
docker compose logs -f

# AIPF만
docker compose logs -f aipf

# 최근 100줄
docker compose logs --tail=100 aiif
```

### 2. 파일 로그 (영구 보관)
```bash
cd /home/dksw/aiapp/data/logs

# AIIF 로그
tail -f aiif/aiif_debug.log    # 일반 로그
tail -f aiif/aiif_trace.log    # API 요청/응답 추적

# AIPF 로그
tail -f aipf/aipf_debug.log    # 일반 로그
tail -f aipf/aipf_trace.log    # API 요청/응답 추적

# 에러만 검색
grep ERROR aiif/aiif_debug.log
grep Exception aipf/aipf_debug.log
```

### 3. 로그 레벨 변경
```bash
# 로그 설정 파일 수정
vi /home/dksw/aiapp/config/app/aiif/log4j2.xml

# <Root level="INFO"> → <Root level="DEBUG">

# 재시작
cd /home/dksw/aiapp/docker
docker compose restart aiif
```

---

## ⚙️ 설정 변경

### 1. 환경 변수 변경

```bash
# AIPF JWT secret 변경 예시
vi /home/dksw/aiapp/config/env/aipf.env
```

변경 후:
```bash
cd /home/dksw/aiapp/docker
docker compose restart aipf
```

### 2. 애플리케이션 설정 변경

```bash
# AIIF 설정 변경
vi /home/dksw/aiapp/config/app/aiif/application-prod.yml
```

예시 - Redis 호스트 변경:
```yaml
spring:
  data:
    redis:
      host: redis    # 컨테이너 이름
      port: 6379
```

변경 후:
```bash
cd /home/dksw/aiapp/docker
docker compose restart aiif
```

**중요**: 설정 파일만 바꾸고 재시작하면 즉시 반영됨. 재빌드 불필요!

### 3. Nginx 설정 변경

```bash
vi /home/dksw/aiapp/config/nginx/conf.d/aiapp.conf
```

변경 후:
```bash
cd /home/dksw/aiapp/docker
docker compose restart nginx
```

---

## 🚀 코드 수정 후 재배포

### 로컬에서 빌드

```bash
cd /Users/ghim/my_business

# AIIF 빌드
cd aiif
mvn clean package -DskipTests

# AIPF 빌드
cd ../aipf
mvn clean package -DskipTests
```

### JAR 파일 교체 (2가지 방법)

#### 방법 1: 전체 재배포 (권장)
```bash
cd /Users/ghim/my_business/docker-new

# 1. JAR 파일 복사
cp ../aiif/target/dksw_aiif.jar apps/aiif/target/aiif-1.0.0.jar
cp ../aipf/target/dksw_aipf.jar apps/aipf/target/aipf-1.0.0.jar

# 2. 압축
tar -czf /tmp/aiapp-deploy.tar.gz config/ docker/ apps/

# 3. SSH agent에 키 추가 (세션마다 1번)
ssh-add ~/.ssh/my_business_deploy

# 4. 서버 전송
scp /tmp/aiapp-deploy.tar.gz dksw@223.130.151.39:/tmp/

# 5. 서버에서 배포
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39 << 'ENDSSH'
cd /home/dksw/aiapp/docker
docker compose down
cd /home/dksw/aiapp
rm -rf apps docker
tar -xzf /tmp/aiapp-deploy.tar.gz apps/ docker/
rm /tmp/aiapp-deploy.tar.gz
cd docker
docker compose up -d --build
docker compose ps
ENDSSH
```

#### 방법 2: JAR만 교체 (빠름)
```bash
cd /Users/ghim/my_business

# SSH agent에 키 추가
ssh-add ~/.ssh/my_business_deploy

# JAR 전송
scp aiif/target/dksw_aiif.jar dksw@223.130.151.39:/tmp/aiif.jar
scp aipf/target/dksw_aipf.jar dksw@223.130.151.39:/tmp/aipf.jar

# 서버에서 교체 및 재시작
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39 << 'ENDSSH'
cd /home/dksw/aiapp
cp /tmp/aiif.jar apps/aiif/target/aiif-1.0.0.jar
cp /tmp/aipf.jar apps/aipf/target/aipf-1.0.0.jar
rm /tmp/*.jar
cd docker
docker compose up -d --build
docker compose ps
ENDSSH
```

---

## 🔄 컨테이너 관리

### 재시작
```bash
cd /home/dksw/aiapp/docker

# 전체 재시작
docker compose restart

# 특정 서비스만
docker compose restart aiif
docker compose restart aipf
```

### 중지 / 시작
```bash
# 전체 중지
docker compose stop

# 전체 시작
docker compose start

# 특정 서비스
docker compose stop aiif
docker compose start aiif
```

### 완전 삭제 (주의!)
```bash
# 컨테이너만 삭제 (데이터는 유지)
docker compose down

# 컨테이너 + 볼륨 삭제 (DB 데이터도 삭제됨!)
docker compose down -v
```

---

## 🐛 문제 해결

### AIIF/AIPF가 unhealthy

```bash
# 로그 확인
docker compose logs aiif | tail -100

# 흔한 원인:
# 1. MySQL 연결 실패 → config/env/aiif.env 확인
# 2. Redis 연결 실패 → config/env/aiif.env 확인
# 3. 설정 파일 오류 → config/app/aiif/application-prod.yml 확인
```

### MySQL 초기화 필요
```bash
cd /home/dksw/aiapp/docker
docker compose down -v
cd ..
rm -rf data/mysql/*
cd docker
docker compose up -d
```

### 디스크 공간 부족
```bash
# 디스크 확인
df -h

# 오래된 Docker 이미지 삭제
docker image prune -a

# 사용 안 하는 컨테이너 삭제
docker container prune
```

### Nginx 설정 오류
```bash
# 설정 테스트
docker compose exec nginx nginx -t

# 오류 나면 설정 파일 확인
vi /home/dksw/aiapp/config/nginx/conf.d/aiapp.conf
```

---

## 🔐 보안

### MySQL 비밀번호 변경
```bash
vi /home/dksw/aiapp/config/env/db.env
# MYSQL_ROOT_PASSWORD, MYSQL_PASSWORD 변경

# 기존 DB 삭제 후 재시작 필요
cd /home/dksw/aiapp/docker
docker compose down -v
docker compose up -d
```

### JWT Secret 변경
```bash
vi /home/dksw/aiapp/config/env/aipf.env
# JWT_SECRET 변경

cd /home/dksw/aiapp/docker
docker compose restart aipf
```

---

## 📊 모니터링

### 컨테이너 리소스 확인
```bash
docker stats --no-stream
```

### 시스템 리소스
```bash
# 메모리
free -h

# 디스크
df -h

# CPU
top
```

### 헬스체크
```bash
# 로컬에서
curl -k https://223.130.151.39/health

# 서버에서
docker compose ps
```

---

## 💾 백업

### 중요 백업 대상
```bash
# 1. MySQL 데이터
/home/dksw/aiapp/data/mysql/

# 2. 설정 파일
/home/dksw/aiapp/config/

# 3. 로그 (선택)
/home/dksw/aiapp/data/logs/
```

### 백업 명령어
```bash
cd /home/dksw
tar -czf aiapp-backup-$(date +%Y%m%d).tar.gz aiapp/data aiapp/config
```

---

## 🎯 핵심 포인트

1. **설정 변경**: `config/` 디렉토리 파일만 수정 → 재시작
2. **코드 변경**: JAR 빌드 → 전송 → 재빌드
3. **로그**: `data/logs/` 또는 `docker compose logs`
4. **재배포**: 압축 전송 → 해제 → `docker compose up -d --build`
5. **SSH**: ssh-agent에 키 추가 필수

---

## 📞 빠른 명령어 모음

```bash
# 서버 접속
ssh -i ~/.ssh/my_business_deploy dksw@223.130.151.39

# 상태 확인
cd /home/dksw/aiapp/docker && docker compose ps

# 로그 확인
docker compose logs -f aipf

# 재시작
docker compose restart aipf

# 로그 파일 확인
tail -f ../data/logs/aipf/aipf-error.log
```
