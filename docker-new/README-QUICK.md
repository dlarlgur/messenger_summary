# AI 플랫폼 Docker 배포 (Production-Ready)

## ⚡ 빠른 배포

압축 파일이 준비되었습니다: `/tmp/aiapp-deploy.tar.gz` (91MB)

### 1. 파일 전송
```bash
scp /tmp/aiapp-deploy.tar.gz dksw@223.130.151.39:/tmp/
# 비밀번호: dksw.123
```

### 2. 서버에서 실행
```bash
ssh dksw@223.130.151.39
# 비밀번호: dksw.123
```

아래 전체를 복사-붙여넣기:
```bash
cd /home/dksw/aiapp/docker 2>/dev/null && docker-compose down -v || echo "OK"
cd /home/dksw
[ -d "aiapp" ] && mv aiapp aiapp.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || rm -rf aiapp
mkdir -p aiapp && cd aiapp
tar -xzf /tmp/aiapp-deploy.tar.gz && rm /tmp/aiapp-deploy.tar.gz
mkdir -p data/{mysql,redis,logs/{aiif,aipf}}
cd docker
docker-compose up -d --build
docker-compose ps
```

### 3. 확인
```bash
# 로그 확인
docker-compose logs -f

# 헬스체크 (로컬에서)
curl http://223.130.151.39:1024/actuator/health
curl http://223.130.151.39:2022/actuator/health
```

---

## 📂 디렉토리 구조

```
/home/dksw/aiapp/
├── config/              # 모든 설정 (운영과 완전 분리)
│   ├── env/            # 환경 변수 (DB, Redis 등)
│   ├── app/            # application.yml, log4j2.xml
│   ├── nginx/          # Nginx 설정
│   ├── mysql/          # DB 초기화
│   └── redis/          # Redis 설정
│
├── docker/             # docker-compose.yml
├── apps/               # JAR + Dockerfile
└── data/               # 영구 데이터 (백업 대상)
    ├── mysql/
    ├── redis/
    └── logs/
```

---

## 🎯 핵심 특징

### ✅ 설정 완전 분리
- `application.yml`, `log4j2.xml` 모두 JAR 외부
- 설정 변경 시 재빌드 불필요
- 컨테이너 재시작만으로 즉시 반영

### ✅ 환경별 전환
```bash
# dev → prod 전환
cp -r config/env-prod/* config/env/
docker-compose restart
```

### ✅ 로그 관리
- 컨테이너 외부에 로그 저장
- 컨테이너 재시작해도 로그 유지
- 실시간 로그 레벨 변경 가능

---

## 🔧 운영 명령어

### 서비스 관리
```bash
cd /home/dksw/aiapp/docker

# 상태 확인
docker-compose ps

# 재시작
docker-compose restart

# 로그
docker-compose logs -f aiif
docker-compose logs -f aipf

# 중지/시작
docker-compose stop
docker-compose start
```

### 설정 변경
```bash
# 환경 변수 변경
vi /home/dksw/aiapp/config/env/aiif.env
docker-compose restart aiif

# 로그 레벨 변경
vi /home/dksw/aiapp/config/app/aiif/log4j2.xml
docker-compose restart aiif

# Nginx 설정
vi /home/dksw/aiapp/config/nginx/conf.d/aiapp.conf
docker-compose restart nginx
```

---

## 🌐 서비스 URL

- **AIIF**: http://223.130.151.39:1024
- **AIPF**: http://223.130.151.39:2022
- **Nginx**: http://223.130.151.39:80
- **MySQL**: 223.130.151.39:3306
- **Redis**: 223.130.151.39:6379

---

## 🐛 문제 해결

### 컨테이너가 안 올라올 때
```bash
docker-compose logs mysql
docker-compose logs aiif
```

### MySQL 초기화 필요
```bash
docker-compose down -v
rm -rf ../data/mysql/*
docker-compose up -d --build
```

### 전체 재배포
```bash
cd /home/dksw
rm -rf aiapp
# 1단계부터 다시 시작
```

---

## 📚 상세 문서

- [배포_실행_가이드.md](./배포_실행_가이드.md) - 단계별 상세 가이드
- [README.md](./README.md) - 전체 아키텍처 및 운영 가이드
- [DEPLOY_NOW.md](./DEPLOY_NOW.md) - 대체 배포 방법

---

## 🔑 서버 정보

- **Host**: 223.130.151.39
- **User**: dksw
- **Password**: dksw.123
- **Root**: root / aime.123

---

## 💡 왜 이 구조인가?

기존 구조의 문제:
- ❌ `.env` 하나에 모든 설정
- ❌ `application.yml`이 JAR 안에 포함
- ❌ 설정 변경 = 재빌드 = 배포 지옥
- ❌ 환경 분리 불가능

새 구조의 장점:
- ✅ 설정 완전 외부화
- ✅ 환경별 전환 용이
- ✅ 재빌드 불필요
- ✅ 로그 영구 보관
- ✅ Kubernetes 전환 가능

---

**이 구조는 Production-Ready입니다.**
