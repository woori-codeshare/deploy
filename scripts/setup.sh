#!/bin/bash

# 환경 설정 파일 생성 관련 함수들
# 작성일: 2025-06-15

# 현재 스크립트의 디렉토리를 기준으로 common.sh 로드
local_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$local_script_dir/common.sh"

# Docker Compose 파일 생성
create_docker_compose() {
    if file_exists "docker-compose.yml"; then
        if ! confirm_action "기존 docker-compose.yml을 덮어쓰시겠습니까?"; then
            log_info "기존 Docker Compose 설정을 사용합니다."
            return 0
        fi
        create_backup "docker-compose.yml"
    fi
    
    log_info "Docker Compose 설정 파일 생성 중..."
    
    cat > docker-compose.yml << 'EOF'
services:
  # MySQL Database
  database:
    image: mysql:8.0
    container_name: woori-codeshare-db
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: woori_codeshare
      MYSQL_USER: woori
      MYSQL_PASSWORD: woori123
      TZ: Asia/Seoul
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./db/init:/docker-entrypoint-initdb.d
    command: --default-authentication-plugin=mysql_native_password --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    restart: unless-stopped
    networks:
      - woori-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      timeout: 20s
      retries: 10

  # Spring Boot Server
  server:
    build:
      context: ./server
      dockerfile: Dockerfile
    container_name: woori-codeshare-server
    environment:
      - SPRING_PROFILES_ACTIVE=docker
      - TZ=Asia/Seoul
      - JAVA_OPTS=-Xmx1g -Xms512m
    ports:
      - "8080:8080"
    depends_on:
      database:
        condition: service_healthy
    volumes:
      - ./server/logs:/app/logs
    restart: unless-stopped
    networks:
      - woori-network
    healthcheck:
      test: ["CMD-SHELL", "timeout 5 bash -c '</dev/tcp/localhost/8080' || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 90s

  # Next.js Client
  client:
    build:
      context: ./client
      dockerfile: Dockerfile
    container_name: woori-codeshare-client
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_API_URL=http://server:8080
      - NEXT_PUBLIC_WS_URL=ws://localhost:8080/ws/websocket
    ports:
      - "3000:3000"
    depends_on:
      server:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - woori-network

volumes:
  mysql_data:
    driver: local

networks:
  woori-network:
    driver: bridge
EOF
    
    log_success "Docker Compose 설정 파일 생성 완료"
}

# 데이터베이스 초기화 스크립트 생성
create_database_init() {
    if ! dir_exists "db"; then
        mkdir -p db/init
    fi
    
    if ! dir_exists "db/init"; then
        mkdir -p db/init
    fi
    
    if file_exists "db/init/init.sql"; then
        if ! confirm_action "기존 데이터베이스 초기화 스크립트를 덮어쓰시겠습니까?"; then
            log_info "기존 데이터베이스 초기화 스크립트를 사용합니다."
            return 0
        fi
        create_backup "db/init/init.sql"
    fi
    
    log_info "데이터베이스 초기화 스크립트 생성 중..."
    
    cat > db/init/init.sql << 'EOF'
-- Woori CodeShare Database Initialization Script
-- 작성일: 2025-06-15

-- 데이터베이스 인코딩 설정
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- 데이터베이스 사용
USE woori_codeshare;

-- 시간대 설정
SET time_zone = '+09:00';

-- 기본 설정 확인
SELECT 
    @@character_set_database as database_charset,
    @@collation_database as database_collation,
    @@time_zone as timezone,
    NOW() as `current_time`;

-- 사용자 권한 확인
SHOW GRANTS FOR 'woori'@'%';

-- 초기화 완료 로그 (간단한 확인용)
SELECT 'Woori CodeShare Database Initialization Completed!' as status;
EOF
    
    log_success "데이터베이스 초기화 스크립트 생성 완료"
}

# Client 환경 파일 생성
create_client_env() {
    if ! dir_exists "client"; then
        log_error "client 디렉토리가 없습니다."
        return 1
    fi
    
    if file_exists "client/.env.local"; then
        if ! confirm_action "기존 Client 환경 파일을 덮어쓰시겠습니까?"; then
            log_info "기존 Client 환경 파일을 사용합니다."
            return 0
        fi
        create_backup "client/.env.local"
    fi
    
    log_info "Client 환경 파일 생성 중..."
    
    cat > client/.env.local << 'EOF'
# API 서버 URL (Docker 내부 통신용)
NEXT_PUBLIC_API_URL=http://server:8080

# WebSocket URL (브라우저에서 직접 접근용)
NEXT_PUBLIC_WS_URL=ws://localhost:8080/ws/websocket
EOF
    
    log_success "Client 환경 파일 생성 완료"
}

# Server 설정 파일 생성 (secret.yml이 없는 경우)
create_server_config() {
    if ! dir_exists "server/src/main/resources"; then
        log_warning "server/src/main/resources 디렉토리가 없습니다."
        return 1
    fi
    
    if file_exists "server/src/main/resources/secret.yml"; then
        log_info "기존 Server 설정 파일을 사용합니다."
        return 0
    fi
    
    log_info "Server 설정 파일 생성 중..."
    
    cat > server/src/main/resources/secret.yml << 'EOF'
# Spring Boot 서버 설정 파일
# 작성일: 2025-06-15

spring:
  profiles:
    active: docker

  autoconfigure:
    exclude:
      - org.springframework.boot.actuate.autoconfigure.metrics.SystemMetricsAutoConfiguration
      - org.springframework.boot.actuate.autoconfigure.metrics.web.tomcat.TomcatMetricsAutoConfiguration

  server:
    port: 8080
    connection-timeout: 15m

  jackson:
    time-zone: Asia/Seoul

  datasource:
    url: jdbc:mysql://database:3306/woori_codeshare?characterEncoding=UTF-8&serverTimezone=Asia/Seoul
    username: woori
    password: woori123
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000

  jpa:
    hibernate:
      ddl-auto: update
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQL8Dialect
        show_sql: false
        format_sql: false
    open-in-view: false

  logging:
    level:
      root: INFO
      com.woori.codeshare: INFO
      org.springframework.web.socket: WARN
      org.springframework.messaging: WARN
    pattern:
      console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
      file: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
    file:
      name: /app/logs/application.log
    logback:
      rollingpolicy:
        max-file-size: 100MB
        max-history: 30

  springdoc:
    default-consumes-media-type: application/json;charset=UTF-8
    default-produces-media-type: application/json;charset=UTF-8
    swagger-ui:
      path: /
      disable-swagger-default-url: true
      display-request-duration: true
      operations-sorter: alpha

# Actuator configuration for basic monitoring
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
      base-path: /actuator
  endpoint:
    health:
      show-details: always
  metrics:
    enable:
      # Disable problematic metrics that cause CGroup issues in Docker
      system: false
      process: false
      tomcat: false
      # Keep safe metrics
      jvm: true
      http: true
      logback: true
EOF
    
    log_success "Server 설정 파일 생성 완료"
}

# 모든 환경 설정 파일 생성
create_all_configs() {
    log_info "환경 설정 파일들을 생성합니다..."
    
    create_docker_compose
    create_database_init
    create_client_env
    create_server_config
    
    log_success "모든 환경 설정 파일 생성 완료"
}

# 설정 파일 상태 확인
check_config_status() {
    echo ""
    log_info "📝 설정 파일 상태 확인"
    echo "=================================="
    
    # Docker Compose
    if file_exists "docker-compose.yml"; then
        echo "docker-compose.yml:  ✅ 존재"
    else
        echo "docker-compose.yml:  ❌ 없음"
    fi
    
    # Database Init
    if file_exists "db/init/init.sql"; then
        echo "DB Init Script:      ✅ 존재"
    else
        echo "DB Init Script:      ❌ 없음"
    fi
    
    # Client Env
    if file_exists "client/.env.local"; then
        echo "Client Env:          ✅ 존재"
    else
        echo "Client Env:          ❌ 없음"
    fi
    
    # Server Config
    if file_exists "server/src/main/resources/secret.yml"; then
        echo "Server Config:       ✅ 존재"
    else
        echo "Server Config:       ❌ 없음"
    fi
    
    echo ""
}
