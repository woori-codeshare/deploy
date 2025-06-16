#!/bin/bash

# GitHub 저장소 클론 관련 함수들
# 작성일: 2025-06-15

# 현재 스크립트의 디렉토리를 기준으로 common.sh 로드
local_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$local_script_dir/common.sh"

# GitHub 저장소 URL
CLIENT_REPO="https://github.com/woori-codeshare/client.git"
SERVER_REPO="https://github.com/woori-codeshare/server.git"

# 코드 업데이트 확인
check_code_updates() {
    log_info "코드 업데이트 확인 중..."
    
    local has_updates=false
    
    # Client 저장소 확인
    if dir_exists "client"; then
        cd client
        if [ -d ".git" ]; then
            git fetch origin main &> /dev/null
            if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
                log_info "Client 코드에 업데이트가 있습니다."
                has_updates=true
            fi
        fi
        cd ..
    fi
    
    # Server 저장소 확인
    if dir_exists "server"; then
        cd server
        if [ -d ".git" ]; then
            git fetch origin main &> /dev/null
            if [ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]; then
                log_info "Server 코드에 업데이트가 있습니다."
                has_updates=true
            fi
        fi
        cd ..
    fi
    
    if [ "$has_updates" = true ]; then
        if confirm_action "최신 코드로 업데이트하시겠습니까?"; then
            return 0  # 업데이트 필요
        else
            return 1  # 업데이트 건너뛰기
        fi
    else
        log_success "이미 최신 코드입니다."
        return 1  # 업데이트 불필요
    fi
}

# Client 저장소 클론
clone_client_repository() {
    log_info "Client 코드 클론 중..."
    
    if dir_exists "client"; then
        if confirm_action "기존 Client 디렉토리를 삭제하고 새로 클론하시겠습니까?"; then
            rm -rf client
        else
            log_info "기존 Client 디렉토리를 유지합니다."
            return 0
        fi
    fi
    
    if git clone "$CLIENT_REPO" client; then
        log_success "Client 저장소 클론 완료"
    else
        log_error "Client 저장소 클론에 실패했습니다."
        log_info "저장소 URL: $CLIENT_REPO"
        exit 1
    fi
}

# Server 저장소 클론
clone_server_repository() {
    log_info "Server 코드 클론 중..."
    
    if dir_exists "server"; then
        if confirm_action "기존 Server 디렉토리를 삭제하고 새로 클론하시겠습니까?"; then
            rm -rf server
        else
            log_info "기존 Server 디렉토리를 유지합니다."
            return 0
        fi
    fi
    
    if git clone "$SERVER_REPO" server; then
        log_success "Server 저장소 클론 완료"
    else
        log_error "Server 저장소 클론에 실패했습니다."
        log_info "저장소 URL: $SERVER_REPO"
        exit 1
    fi
}

# 모든 저장소 클론
clone_repositories() {
    log_info "GitHub 저장소에서 코드 다운로드 중..."
    
    # 인터넷 연결 확인
    if ! ping -c 1 github.com &> /dev/null; then
        log_error "인터넷 연결을 확인할 수 없습니다."
        log_info "네트워크 연결 상태를 확인하고 다시 시도하세요."
        exit 1
    fi
    
    clone_client_repository
    clone_server_repository
    
    log_success "GitHub 저장소 클론 완료"
}

# 코드 업데이트 (기존 디렉토리가 있는 경우)
update_repositories() {
    log_info "기존 저장소 업데이트 중..."
    
    # Client 업데이트
    if dir_exists "client"; then
        cd client
        if [ -d ".git" ]; then
            log_info "Client 저장소 업데이트 중..."
            git fetch origin main
            git reset --hard origin/main
            log_success "Client 저장소 업데이트 완료"
        fi
        cd ..
    fi
    
    # Server 업데이트
    if dir_exists "server"; then
        cd server
        if [ -d ".git" ]; then
            log_info "Server 저장소 업데이트 중..."
            git fetch origin main
            git reset --hard origin/main
            log_success "Server 저장소 업데이트 완료"
        fi
        cd ..
    fi
    
    log_success "저장소 업데이트 완료"
}

# 저장소 상태 확인
check_repository_status() {
    echo ""
    log_info "📁 저장소 상태 확인"
    echo "=================================="
    
    # Client 상태
    if dir_exists "client"; then
        cd client
        if [ -d ".git" ]; then
            local client_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            local client_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
            echo "Client:  ✅ $client_branch ($client_commit)"
        else
            echo "Client:  ⚠️  Git 저장소가 아님"
        fi
        cd ..
    else
        echo "Client:  ❌ 디렉토리 없음"
    fi
    
    # Server 상태
    if dir_exists "server"; then
        cd server
        if [ -d ".git" ]; then
            local server_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            local server_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
            echo "Server:  ✅ $server_branch ($server_commit)"
        else
            echo "Server:  ⚠️  Git 저장소가 아님"
        fi
        cd ..
    else
        echo "Server:  ❌ 디렉토리 없음"
    fi
    echo ""
}
