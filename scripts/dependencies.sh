#!/bin/bash

# Node.js 및 Gradle 의존성 관리 함수들
# 작성일: 2025-06-15

# 현재 스크립트의 디렉토리를 기준으로 common.sh 로드
local_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$local_script_dir/common.sh"

# Node.js 패키지 의존성 확인 및 수정
fix_nodejs_dependencies() {
    log_info "Node.js 패키지 의존성 확인 중..."
    
    if ! dir_exists "client"; then
        log_warning "client 디렉토리가 없습니다."
        return 1
    fi
    
    cd client
    
    # package.json 존재 확인
    if ! file_exists "package.json"; then
        log_error "package.json 파일이 없습니다."
        cd ..
        return 1
    fi
    
    # package.json과 lock 파일 동기화 확인
    log_info "패키지 의존성 동기화 확인 중..."
    
    # npm ls로 의존성 문제 확인 (에러 무시)
    if ! npm ls > /dev/null 2>&1; then
        log_warning "패키지 의존성 문제가 발견되었습니다. 자동 수정 중..."
        
        # 기존 lock 파일들 정리
        rm -f package-lock.json pnpm-lock.yaml yarn.lock
        
        # npm을 사용해서 의존성 재설치
        log_info "npm을 사용하여 의존성을 재설치합니다..."
        if npm install; then
            log_success "npm install 완료"
        else
            log_error "npm install 실패"
            cd ..
            return 1
        fi
        
        # Git으로 관리되는 경우 업데이트된 lock 파일 처리
        if [ -d ".git" ] && [ -f "package-lock.json" ]; then
            if git status --porcelain | grep -q "package-lock.json"; then
                log_info "업데이트된 package-lock.json 발견"
                
                if confirm_action "업데이트된 package-lock.json을 커밋하시겠습니까?" "Y"; then
                    git add package-lock.json
                    git commit -m "Fix: Update package-lock.json to sync with package.json"
                    
                    # 원격 저장소에 푸시 (선택적)
                    if confirm_action "업데이트를 GitHub에 푸시하시겠습니까?" "Y"; then
                        if git push origin main; then
                            log_success "패키지 의존성 수정사항이 GitHub에 업데이트되었습니다."
                        else
                            log_warning "GitHub 푸시에 실패했습니다. 수동으로 푸시해주세요."
                        fi
                    fi
                fi
            fi
        fi
        
        log_success "패키지 의존성 문제가 해결되었습니다."
    else
        log_success "패키지 의존성이 정상입니다."
    fi
    
    cd ..
    return 0
}

# Spring Boot Gradle 빌드
build_spring_boot() {
    log_info "Spring Boot 애플리케이션 빌드 중..."
    
    if ! dir_exists "server"; then
        log_error "server 디렉토리가 없습니다."
        return 1
    fi
    
    cd server
    
    # Gradle wrapper 존재 확인
    if ! file_exists "gradlew"; then
        log_error "gradlew 파일이 없습니다."
        cd ..
        return 1
    fi
    
    # Gradle wrapper 실행 권한 확인
    if [[ ! -x "./gradlew" ]]; then
        log_info "gradlew 실행 권한 설정 중..."
        chmod +x ./gradlew
    fi
    
    # OS에 따른 빌드 명령 실행
    log_info "Gradle 빌드 시작 (테스트 제외)..."
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        if ./gradlew.bat clean build -x test; then
            log_success "Spring Boot 빌드 완료"
        else
            log_error "Spring Boot 빌드에 실패했습니다."
            cd ..
            return 1
        fi
    else
        if ./gradlew clean build -x test; then
            log_success "Spring Boot 빌드 완료"
        else
            log_error "Spring Boot 빌드에 실패했습니다."
            cd ..
            return 1
        fi
    fi
    
    # 빌드된 JAR 파일 확인
    if ls build/libs/*.jar 1> /dev/null 2>&1; then
        local jar_file=$(ls build/libs/*.jar | head -1)
        local jar_size=$(du -h "$jar_file" | cut -f1)
        log_success "빌드된 JAR 파일: $(basename "$jar_file") ($jar_size)"
    else
        log_error "빌드된 JAR 파일을 찾을 수 없습니다."
        cd ..
        return 1
    fi
    
    cd ..
    return 0
}

# 의존성 상태 확인
check_dependencies_status() {
    echo ""
    log_info "🔧 의존성 상태 확인"
    echo "=================================="
    
    # Node.js 확인
    if command -v node &> /dev/null; then
        local node_version=$(node --version)
        echo "Node.js:      ✅ $node_version"
    else
        echo "Node.js:      ❌ 설치되지 않음"
    fi
    
    # npm 확인
    if command -v npm &> /dev/null; then
        local npm_version=$(npm --version)
        echo "npm:          ✅ v$npm_version"
    else
        echo "npm:          ❌ 설치되지 않음"
    fi
    
    # Java 확인
    if command -v java &> /dev/null; then
        local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)
        echo "Java:         ✅ $java_version"
    else
        echo "Java:         ❌ 설치되지 않음"
    fi
    
    # Client 의존성 확인
    if dir_exists "client"; then
        cd client
        if file_exists "package.json"; then
            if npm ls > /dev/null 2>&1; then
                echo "Client deps:  ✅ 정상"
            else
                echo "Client deps:  ⚠️  동기화 필요"
            fi
        else
            echo "Client deps:  ❌ package.json 없음"
        fi
        cd ..
    else
        echo "Client deps:  ❌ client 디렉토리 없음"
    fi
    
    # Server 빌드 상태 확인
    if dir_exists "server"; then
        if file_exists "server/build/libs" && ls server/build/libs/*.jar 1> /dev/null 2>&1; then
            echo "Server build: ✅ 빌드됨"
        else
            echo "Server build: ⚠️  빌드 필요"
        fi
    else
        echo "Server build: ❌ server 디렉토리 없음"
    fi
    
    echo ""
}

# 전체 의존성 설치 및 빌드
install_and_build_all() {
    log_info "전체 의존성 설치 및 빌드 시작..."
    
    # Node.js 의존성 해결
    if ! fix_nodejs_dependencies; then
        log_error "Node.js 의존성 해결에 실패했습니다."
        return 1
    fi
    
    # Spring Boot 빌드
    if ! build_spring_boot; then
        log_error "Spring Boot 빌드에 실패했습니다."
        return 1
    fi
    
    log_success "전체 의존성 설치 및 빌드 완료"
    return 0
}

# 의존성 캐시 정리
clean_dependencies() {
    log_info "의존성 캐시 정리 중..."
    
    # Node.js 캐시 정리
    if dir_exists "client"; then
        cd client
        if file_exists "package.json"; then
            log_info "Node.js 캐시 정리 중..."
            rm -rf node_modules package-lock.json pnpm-lock.yaml yarn.lock
            if command -v npm &> /dev/null; then
                npm cache clean --force
            fi
            log_success "Node.js 캐시 정리 완료"
        fi
        cd ..
    fi
    
    # Gradle 캐시 정리
    if dir_exists "server"; then
        cd server
        if file_exists "gradlew"; then
            log_info "Gradle 캐시 정리 중..."
            ./gradlew clean
            rm -rf build
            log_success "Gradle 캐시 정리 완료"
        fi
        cd ..
    fi
    
    log_success "의존성 캐시 정리 완료"
}
