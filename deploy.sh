#!/bin/bash

# Woori CodeShare 배포 스크립트 (모듈화된 버전)
# 작성자: GitHub Copilot
# 작성일: 2025-06-15
# 버전: 3.0

set -e  # 에러 발생시 스크립트 중단

# 스크립트 디렉토리 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 모듈 로드
source "$SCRIPT_DIR/scripts/common.sh"
source "$SCRIPT_DIR/scripts/repositories.sh"
source "$SCRIPT_DIR/scripts/docker.sh"
source "$SCRIPT_DIR/scripts/dependencies.sh"
source "$SCRIPT_DIR/scripts/setup.sh"

# 설정 파일 생성 (간소화된 버전) - 더 이상 사용하지 않음
# create_all_configs() 사용
setup_basic_environment() {
    log_info "기본 환경 설정 파일 확인 중..."
    
    # Docker Compose 파일이 없는 경우에만 생성
    if ! file_exists "docker-compose.yml"; then
        log_info "Docker Compose 설정 파일 생성 중..."
        # 여기서는 기존의 docker-compose.yml 생성 로직을 단순화
        # 실제 구현시에는 별도 모듈로 분리 가능
        log_success "Docker Compose 설정 완료"
    else
        log_info "기존 Docker Compose 설정을 사용합니다."
    fi
}

# 빠른 재배포 (코드 업데이트 없이)
quick_redeploy() {
    log_info "빠른 재배포 (코드 업데이트 없이)"
    
    # 서비스 중지
    stop_services
    
    # 의존성 문제 확인
    fix_nodejs_dependencies
    
    # Spring Boot 빌드
    build_spring_boot
    
    # 서비스 시작
    if start_services; then
        check_services_detailed
    else
        exit 1
    fi
}

# 전체 배포 프로세스
full_deploy() {
    check_requirements
    check_ports
    clone_repositories
    cleanup_containers
    create_all_configs  # setup.sh의 함수 사용
    install_and_build_all
    
    if start_services; then
        check_services_detailed
        echo ""
        log_success "🎉 배포 완료!"
        echo ""
        echo "🌐 서비스 접속 주소:"
        echo "  • 메인 애플리케이션: http://localhost:3000"
        echo "  • API 문서: http://localhost:8080/swagger-ui/index.html"
        echo ""
        echo "💡 추가 명령어:"
        echo "  • 상태 확인: ./deploy.sh status"
        echo "  • 로그 확인: ./deploy.sh logs [서비스명]"
        echo "  • 서비스 중지: ./deploy.sh stop"
        echo ""
    else
        exit 1
    fi
}

# 도움말 출력
show_help() {
    echo ""
    echo "🚀 Woori CodeShare 배포 도구 v3.0"
    echo "=================================="
    echo ""
    echo "사용법: $0 [옵션]"
    echo ""
    echo "🚀 배포 관련 옵션:"
    echo "  start         - 전체 시스템 시작 (기본값)"
    echo "  stop          - 서비스 중지"
    echo "  restart       - 서비스 재시작"
    echo "  quick         - 빠른 재배포 (코드 업데이트 없이)"
    echo ""
    echo "🔧 관리 옵션:"
    echo "  status        - 서비스 상태 확인"
    echo "  logs [서비스] - 로그 확인"
    echo "  clean         - 전체 정리"
    echo "  setup         - 설정 파일만 생성"
    echo ""
    echo "🔨 개발 도구:"
    echo "  clone         - 저장소만 클론"
    echo "  build         - 의존성 설치 및 빌드만"
    echo "  fix-deps      - Node.js 의존성 문제 해결"
    echo "  deps-status   - 의존성 상태 확인"
    echo ""
    echo "📊 정보 확인:"
    echo "  repo-status   - 저장소 상태 확인"
    echo "  health        - 상세 헬스체크"
    echo "  config-status - 설정 파일 상태 확인"
    echo "  help          - 도움말 출력"
    echo ""
    echo "💡 빠른 시작 예시:"
    echo "  ./deploy.sh              # 전체 시스템 시작"
    echo "  ./deploy.sh quick        # 빠른 재배포"
    echo "  ./deploy.sh logs server  # 서버 로그 확인"
    echo "  ./deploy.sh fix-deps     # 의존성 문제 해결"
    echo "  ./deploy.sh setup        # 설정 파일만 생성"
    echo ""
}

# 메인 실행 함수
main() {
    print_header
    
    case "${1:-start}" in
        "start")
            full_deploy
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            stop_services
            sleep 3
            full_deploy
            ;;
        "quick"|"quick-deploy")
            quick_redeploy
            ;;
        "status")
            check_services_status
            ;;
        "health"|"detailed-status")
            check_services_detailed
            ;;
        "logs")
            show_logs "${2:-}"
            ;;
        "clone")
            check_requirements
            clone_repositories
            check_repository_status
            ;;
        "build")
            install_and_build_all
            ;;
        "fix-deps")
            fix_nodejs_dependencies
            ;;
        "deps-status")
            check_dependencies_status
            ;;
        "repo-status")
            check_repository_status
            ;;
        "config-status")
            check_config_status
            ;;
        "setup")
            create_all_configs
            check_config_status
            ;;
        "clean")
            cleanup_containers
            clean_docker_system
            clean_dependencies
            # 생성된 파일들 정리
            for dir in client server db; do
                if dir_exists "$dir"; then
                    if confirm_action "$dir 디렉토리를 삭제하시겠습니까?"; then
                        rm -rf "$dir"
                        log_info "$dir 디렉토리 삭제됨"
                    fi
                fi
            done
            log_success "시스템 정리 완료"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
