FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# 타임존 설정
RUN apk add --no-cache tzdata && \
    cp /usr/share/zoneinfo/Asia/Seoul /etc/localtime && \
    echo "Asia/Seoul" > /etc/timezone && \
    apk del tzdata

# JAR 파일 복사
COPY target/aiif-1.0.0.jar app.jar

# 로그 디렉토리 생성
RUN mkdir -p /logs && chmod 755 /logs

# 헬스체크
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:1309/actuator/health || exit 1

# 외부 설정 파일 주입
ENTRYPOINT ["java", \
    "-Dspring.config.location=/config/application-prod.yml", \
    "-Dlogging.config=/config/log4j2.xml", \
    "-DLOG_PATH=/logs", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-jar", "app.jar"]

EXPOSE 1309
