# 수동 배포 가이드

SSH 자동 인증이 안 될 때 사용하는 단계별 가이드입니다.

## 1단계: 기존 컨테이너 중지

```bash
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

cd /home/dksw/aiapp/docker
docker-compose down -v

exit
```

## 2단계: 서버 디렉토리 생성

```bash
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

mkdir -p /home/dksw/aiapp/{config/{env,app/{aiif,aipf},nginx/conf.d,mysql,redis},docker,data/{mysql,redis,logs/{aiif,aipf}},apps/{aiif/target,aipf/target}}

exit
```

## 3단계: 파일 전송 (로컬에서 실행)

```bash
cd /Users/ghim/my_business/docker-new

# 설정 파일
scp -r config/env dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/app dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/nginx dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/mysql dksw@223.130.151.39:/home/dksw/aiapp/config/
scp -r config/redis dksw@223.130.151.39:/home/dksw/aiapp/config/

# Docker 설정
scp docker/docker-compose.yml dksw@223.130.151.39:/home/dksw/aiapp/docker/

# 애플리케이션
scp apps/aiif/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/apps/aiif/
scp apps/aiif/target/aiif-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/apps/aiif/target/

scp apps/aipf/Dockerfile dksw@223.130.151.39:/home/dksw/aiapp/apps/aipf/
scp apps/aipf/target/aipf-1.0.0.jar dksw@223.130.151.39:/home/dksw/aiapp/apps/aipf/target/
```

비밀번호를 여러 번 입력해야 합니다. 각 명령마다 `dksw.123`

## 4단계: Docker Compose 실행

```bash
ssh dksw@223.130.151.39
# 비밀번호: dksw.123

cd /home/dksw/aiapp/docker

# 컨테이너 빌드 및 실행
docker-compose up -d --build

# 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

## 완료!

서비스 접속:
- AIIF: http://223.130.151.39:1024
- AIPF: http://223.130.151.39:2022
- Nginx: http://223.130.151.39:80

## 문제 해결

### 컨테이너가 안 올라오면
```bash
cd /home/dksw/aiapp/docker
docker-compose logs aiif
docker-compose logs aipf
docker-compose logs mysql
```

### 재시작
```bash
cd /home/dksw/aiapp/docker
docker-compose restart
```
