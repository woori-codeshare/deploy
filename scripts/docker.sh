#!/bin/bash

# Docker 관련 함수들
# 작성일: 2025-06-15

# 현재 스크립트의 디렉토리를 기준으로 common.sh 로드
local_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$local_script_dir/common.sh"

# 기존 컨테이너 정리
cleanup_containers() {
    log_info "기존 컨테이너 정리 중..."
    
    local compose_cmd=$(get_docker_compose_cmd)
    
    # 실행 중인 서비스 확인
    if $compose_cmd ps -q &> /dev/null; then
        log_info "실행 중인 서비스를 중지합니다..."
        $compose_cmd down --remove-orphans --volumes
    fi
    
    # 사용하지 않는 이미지 정리 (선택적)
    if confirm_action "사용하지 않는 Docker 이미지를 정리하시겠습니까?"; then
        docker image prune -f
        log_success "Docker 이미지 정리 완료"
    fi
    
    log_success "컨테이너 정리 완료"
}

# 서비스 시작
start_services() {
    log_info "Docker Compose로 서비스 시작 중..."
    log_info "이 과정은 몇 분 정도 소요될 수 있습니다..."
    
    local compose_cmd=$(get_docker_compose_cmd)
    
    # 서비스 시작 (빌드 포함) - 에러 발생시 상세 로그 출력
    if $compose_cmd up --build -d; then
        log_success "서비스 배포 완료"
        return 0
    else
        log_error "서비스 배포에 실패했습니다."
        echo ""
        log_info "🔍 문제 해결을 위한 상세 로그:"
        $compose_cmd logs --tail=20
        echo ""
        log_info "💡 일반적인 해결 방법:"
        echo "  1. Client 의존성 문제: ./run.sh fix-deps"
        echo "  2. 포트 충돌: 다른 서비스가 3000, 8080 포트를 사용하고 있는지 확인"
        echo "  3. Docker 메모리 부족: Docker Desktop에서 메모리 할당량 증가"
        echo "  4. 전체 정리 후 재시도: ./run.sh clean && ./run.sh start"
        return 1
    fi
}

# 서비스 중지
stop_services() {
    log_info "서비스 중지 중..."
    
    local compose_cmd=$(get_docker_compose_cmd)
    
    if $compose_cmd ps -q &> /dev/null; then
        $compose_cmd down
        log_success "서비스 중지 완료"
    else
        log_info "실행 중인 서비스가 없습니다."
    fi
}

# 서비스 재시작
restart_services() {
    log_info "서비스 재시작 중..."
    
    local compose_cmd=$(get_docker_compose_cmd)
    
    $compose_cmd restart
    log_success "서비스 재시작 완료"
}

# 서비스 상태 확인
check_services_status() {
    echo ""
    log_info "🐳 서비스 상태 확인"
    echo "=================================="
    
    local compose_cmd=$(get_docker_compose_cmd)
    
    if $compose_cmd ps 2>/dev/null; then
        echo ""
        log_info "📊 포트 사용 현황:"
        echo "  http://localhost:3000  - Next.js Client"
        echo "  http://localhost:8080  - Spring Boot Server"
        echo "  http://localhost:3306  - MySQL Database"
        echo ""
    else
        log_warning "실행 중인 서비스가 없습니다."
        echo ""
    fi
}

# 상세 서비스 상태 확인
check_services_detailed() {
    check_services_status
    
    echo ""
    log_info "🏥 상세 서비스 헬스체크"
    echo "=================================="
    
    # Spring Boot Health Check
    if timeout 5 bash -c '</dev/tcp/localhost/8080' 2>/dev/null; then
        if curl -s http://localhost:8080/actuator/health &> /dev/null; then
            local health_status=$(curl -s http://localhost:8080/actuator/health | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$health_status" = "UP" ]; then
                echo "Spring Boot:  ✅ Health Check 통과 ($health_status)"
            else
                echo "Spring Boot:  ⚠️  Health Check 실패 ($health_status)"
            fi
        else
            echo "Spring Boot:  ✅ 포트 응답 (Actuator 확인 필요)"
        fi
    else
        echo "Spring Boot:  ❌ 응답 없음 (서비스 시작 중이거나 오류)"
    fi
    
    # Next.js Client Check
    if curl -s http://localhost:3000 &> /dev/null; then
        echo "Next.js:      ✅ 정상 응답"
    else
        echo "Next.js:      ❌ 응답 없음"
    fi
    
    # MySQL Check (포트 확인)
    if nc -z localhost 3306 2>/dev/null; then
        echo "MySQL:        ✅ 포트 응답"
    else
        echo "MySQL:        ❌ 포트 응답 없음"
    fi
    
    echo ""
}

# 로그 확인
show_logs() {
    local service="$1"
    local compose_cmd=$(get_docker_compose_cmd)
    
    if [ -z "$service" ]; then
        log_info "전체 서비스 로그 (최근 50줄):"
        $compose_cmd logs --tail=50
    else
        case "$service" in
            "server"|"backend")
                log_info "Spring Boot Server 로그:"
                $compose_cmd logs --tail=100 server
                ;;
            "client"|"frontend")
                log_info "Next.js Client 로그:"
                $compose_cmd logs --tail=100 client
                ;;
            "database"|"db"|"mysql")
                log_info "MySQL Database 로그:"
                $compose_cmd logs --tail=100 database
                ;;
            *)
                log_error "알 수 없는 서비스: $service"
                echo "사용 가능한 서비스: server, client, database"
                exit 1
                ;;
        esac
    fi
}

# Docker 시스템 정리
clean_docker_system() {
    log_info "Docker 시스템 전체 정리 중..."
    
    # 컨테이너 정리
    cleanup_containers
    
    # 시스템 정리
    if confirm_action "사용하지 않는 Docker 리소스를 모두 정리하시겠습니까? (이미지, 볼륨, 네트워크 포함)"; then
        docker system prune -af --volumes
        log_success "Docker 시스템 정리 완료"
    fi
}
