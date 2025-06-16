#!/bin/bash

# 공통 유틸리티 함수들
# 작성일: 2025-06-15

# 색상 코드 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 헤더 출력
print_header() {
    echo -e "${BLUE}"
    echo "================================================="
    echo "     Woori CodeShare 배포 스크립트"
    echo "================================================="
    echo -e "${NC}"
}

# Docker Compose 명령어 감지
get_docker_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# 도커 및 도커 컴포즈 확인
check_requirements() {
    log_info "시스템 요구사항 확인 중..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되어 있지 않습니다."
        log_info "Docker 설치 가이드: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "Git이 설치되어 있지 않습니다."
        log_info "Git 설치 가이드: https://git-scm.com/downloads"
        exit 1
    fi
    
    # Docker 서비스 실행 확인
    if ! docker info &> /dev/null; then
        log_error "Docker 서비스가 실행되지 않고 있습니다."
        log_info "Docker Desktop을 시작하거나 'sudo systemctl start docker'를 실행하세요."
        exit 1
    fi
    
    log_success "시스템 요구사항 확인 완료"
}

# 포트 사용 확인
check_ports() {
    local ports=("3000" "8080" "3306")
    local used_ports=()
    
    for port in "${ports[@]}"; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            used_ports+=($port)
        fi
    done
    
    if [ ${#used_ports[@]} -gt 0 ]; then
        log_warning "다음 포트가 사용 중입니다: ${used_ports[*]}"
        echo "  3000: Next.js Client"
        echo "  8080: Spring Boot Server"
        echo "  3306: MySQL Database"
        echo ""
        read -p "계속 진행하시겠습니까? (y/N): " continue_anyway
        if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
            log_info "배포가 중단되었습니다."
            exit 1
        fi
    fi
}

# 사용자 확인 대화상자
confirm_action() {
    local message="$1"
    local default="${2:-N}"
    
    if [ "$default" = "Y" ]; then
        read -p "$message (Y/n): " response
        [[ ! $response =~ ^[Nn]$ ]]
    else
        read -p "$message (y/N): " response
        [[ $response =~ ^[Yy]$ ]]
    fi
}

# 파일 존재 확인
file_exists() {
    [ -f "$1" ]
}

# 디렉토리 존재 확인
dir_exists() {
    [ -d "$1" ]
}

# 백업 파일 생성
create_backup() {
    local file="$1"
    if file_exists "$file"; then
        local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup_file"
        log_info "백업 파일 생성: $backup_file"
    fi
}
