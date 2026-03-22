#!/usr/bin/env bash
# ============================================================================
# 🚀 combo-cliproxy — Cloud Run Auto Deploy Script
# ============================================================================
# Automates:
#   1. GCP Project setup (create project, enable APIs, set billing)
#   2. Build & Deploy to Cloud Run (Docker build, push, deploy)
#   3. Full setup (1 + 2 combined)
#   4. Cleanup resources (delete VM, firewall, service)
#
# Usage: ./deploy.sh
# ============================================================================

set -euo pipefail

# ─── Colors & Formatting ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ─── Default Configuration ──────────────────────────────────────────────────
# Override these via environment variables or the interactive menu
DEFAULT_PROJECT_ID="maxai-omi-2026"
DEFAULT_REGION="us-west1"
DEFAULT_SERVICE_NAME="combo-cliproxy"
DEFAULT_IMAGE_NAME="combo-cliproxy"
DEFAULT_PORT="20128"
DEFAULT_MEMORY="512Mi"
DEFAULT_CPU="1"
DEFAULT_MIN_INSTANCES="0"
DEFAULT_MAX_INSTANCES="2"
DEFAULT_INITIAL_PASSWORD="123456"
DEFAULT_REPO_URL="https://github.com/decolua/9router"
DEFAULT_DOCKERFILE_PATH="/tmp/9router-deploy/Dockerfile"

# ─── Runtime Variables (populated during execution) ──────────────────────────
PROJECT_ID=""
REGION=""
SERVICE_NAME=""
IMAGE_NAME=""
PORT=""
MEMORY=""
CPU=""
MIN_INSTANCES=""
MAX_INSTANCES=""
INITIAL_PASSWORD=""
REPO_URL=""
DOCKERFILE_PATH=""
BILLING_ACCOUNT=""

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🚀 combo-cliproxy — Cloud Run Auto Deploy${NC}                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${DIM}Automated GCP Project Setup & Deployment${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${MAGENTA}━━━ $1 ━━━${NC}"
}

# Ask a question with a default value. If user presses Enter, use default.
ask() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local input

    echo -ne "${CYAN}?${NC} ${prompt} ${DIM}[${default}]${NC}: "
    read -r input
    if [[ -z "$input" ]]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

# Ask yes/no with default
ask_yn() {
    local prompt="$1"
    local default="$2"  # y or n
    local result

    if [[ "$default" == "y" ]]; then
        echo -ne "${CYAN}?${NC} ${prompt} ${DIM}[Y/n]${NC}: "
    else
        echo -ne "${CYAN}?${NC} ${prompt} ${DIM}[y/N]${NC}: "
    fi
    read -r result
    if [[ -z "$result" ]]; then
        result="$default"
    fi
    [[ "${result,,}" == "y" || "${result,,}" == "yes" ]]
}

# Select from a list
select_option() {
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "${CYAN}?${NC} ${prompt}:"
    for i in "${!options[@]}"; do
        echo -e "  ${BOLD}$((i + 1)))${NC} ${options[$i]}"
    done
    echo -ne "${CYAN}→${NC} Chọn (1-${#options[@]}): "
    read -r choice
    echo "$choice"
}

# Check if a command exists
require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        log_error "Missing required command: $1"
        echo -e "  Install it: $2"
        exit 1
    fi
}

# Print current config summary
print_config() {
    echo ""
    echo -e "${BOLD}📋 Configuration Summary:${NC}"
    echo -e "  ├── Project ID:     ${GREEN}${PROJECT_ID}${NC}"
    echo -e "  ├── Region:         ${GREEN}${REGION}${NC}"
    echo -e "  ├── Service:        ${GREEN}${SERVICE_NAME}${NC}"
    echo -e "  ├── Image:          ${GREEN}${IMAGE_NAME}${NC}"
    echo -e "  ├── Port:           ${GREEN}${PORT}${NC}"
    echo -e "  ├── Memory:         ${GREEN}${MEMORY}${NC}"
    echo -e "  ├── CPU:            ${GREEN}${CPU}${NC}"
    echo -e "  ├── Min Instances:  ${GREEN}${MIN_INSTANCES}${NC}"
    echo -e "  ├── Max Instances:  ${GREEN}${MAX_INSTANCES}${NC}"
    echo -e "  ├── Password:       ${GREEN}${INITIAL_PASSWORD}${NC}"
    echo -e "  ├── Repo:           ${GREEN}${REPO_URL}${NC}"
    echo -e "  └── Dockerfile:     ${GREEN}${DOCKERFILE_PATH}${NC}"
    echo ""
}

# ============================================================================
# Configuration Collection
# ============================================================================

collect_config() {
    log_step "⚙️  Configuration"

    ask "GCP Project ID" "$DEFAULT_PROJECT_ID" "PROJECT_ID"
    ask "Region" "$DEFAULT_REGION" "REGION"
    ask "Service name" "$DEFAULT_SERVICE_NAME" "SERVICE_NAME"
    ask "Docker image name" "$DEFAULT_IMAGE_NAME" "IMAGE_NAME"
    ask "Application port" "$DEFAULT_PORT" "PORT"
    ask "Memory" "$DEFAULT_MEMORY" "MEMORY"
    ask "CPU" "$DEFAULT_CPU" "CPU"
    ask "Min instances" "$DEFAULT_MIN_INSTANCES" "MIN_INSTANCES"
    ask "Max instances" "$DEFAULT_MAX_INSTANCES" "MAX_INSTANCES"
    ask "Initial password" "$DEFAULT_INITIAL_PASSWORD" "INITIAL_PASSWORD"
    ask "Source repo URL" "$DEFAULT_REPO_URL" "REPO_URL"
    ask "Dockerfile path" "$DEFAULT_DOCKERFILE_PATH" "DOCKERFILE_PATH"

    print_config

    if ! ask_yn "Proceed with this configuration?" "y"; then
        log_warn "Aborted by user."
        exit 0
    fi
}

collect_config_fast() {
    # Use all defaults, no questions asked
    PROJECT_ID="$DEFAULT_PROJECT_ID"
    REGION="$DEFAULT_REGION"
    SERVICE_NAME="$DEFAULT_SERVICE_NAME"
    IMAGE_NAME="$DEFAULT_IMAGE_NAME"
    PORT="$DEFAULT_PORT"
    MEMORY="$DEFAULT_MEMORY"
    CPU="$DEFAULT_CPU"
    MIN_INSTANCES="$DEFAULT_MIN_INSTANCES"
    MAX_INSTANCES="$DEFAULT_MAX_INSTANCES"
    INITIAL_PASSWORD="$DEFAULT_INITIAL_PASSWORD"
    REPO_URL="$DEFAULT_REPO_URL"
    DOCKERFILE_PATH="$DEFAULT_DOCKERFILE_PATH"

    print_config
}

# ============================================================================
# 1. GCP Project Setup
# ============================================================================

setup_gcp_project() {
    log_step "🏗️  Step 1: GCP Project Setup"

    # Check if project already exists
    if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        log_success "Project '$PROJECT_ID' already exists"
    else
        log_info "Creating project '$PROJECT_ID'..."
        gcloud projects create "$PROJECT_ID" --name="$PROJECT_ID" --quiet
        log_success "Project created: $PROJECT_ID"
    fi

    # Set project
    log_info "Setting active project to '$PROJECT_ID'..."
    gcloud config set project "$PROJECT_ID" --quiet
    log_success "Active project: $PROJECT_ID"

    # Link billing (if needed)
    log_step "💳 Billing Account"
    local billing_linked
    billing_linked=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")

    if [[ -n "$billing_linked" && "$billing_linked" != "" ]]; then
        log_success "Billing already linked: $billing_linked"
    else
        log_warn "No billing account linked."
        echo ""
        # List available billing accounts
        log_info "Available billing accounts:"
        gcloud billing accounts list --format="table(name, displayName, open)" 2>/dev/null || true
        echo ""

        if ask_yn "Link a billing account now?" "y"; then
            ask "Billing Account ID (e.g. 012345-6789AB-CDEF01)" "" "BILLING_ACCOUNT"
            if [[ -n "$BILLING_ACCOUNT" ]]; then
                gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT" --quiet
                log_success "Billing linked: $BILLING_ACCOUNT"
            else
                log_warn "Skipped billing setup. Some APIs may not work."
            fi
        fi
    fi

    # Enable required APIs
    log_step "🔌 Enabling APIs"
    local apis=(
        "run.googleapis.com"
        "cloudbuild.googleapis.com"
        "artifactregistry.googleapis.com"
        "containerregistry.googleapis.com"
    )

    for api in "${apis[@]}"; do
        log_info "Enabling ${api}..."
        gcloud services enable "$api" --project="$PROJECT_ID" --quiet 2>/dev/null && \
            log_success "Enabled: $api" || \
            log_warn "Could not enable: $api (may need billing)"
    done

    # Create Artifact Registry repo (if not exists)
    log_step "📦 Artifact Registry"
    if gcloud artifacts repositories describe docker-repo \
        --location="$REGION" \
        --project="$PROJECT_ID" &>/dev/null; then
        log_success "Artifact Registry repo 'docker-repo' already exists"
    else
        log_info "Creating Artifact Registry repository..."
        gcloud artifacts repositories create docker-repo \
            --repository-format=docker \
            --location="$REGION" \
            --project="$PROJECT_ID" \
            --description="Docker images for combo-cliproxy" \
            --quiet
        log_success "Created Artifact Registry repo: docker-repo"
    fi

    # Configure Docker auth
    log_info "Configuring Docker authentication..."
    gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet 2>/dev/null
    log_success "Docker authentication configured"

    echo ""
    log_success "✅ GCP Project Setup Complete!"
}

# ============================================================================
# 2. Build & Deploy
# ============================================================================

build_and_deploy() {
    log_step "🐳 Step 2: Build & Deploy"

    local IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/docker-repo/${IMAGE_NAME}"
    local IMAGE_TAG="${IMAGE_URI}:latest"
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    local IMAGE_TAG_VERSIONED="${IMAGE_URI}:${TIMESTAMP}"

    # ─── Source Code ─────────────────────────────────────────────────────
    log_step "📥 Source Code"

    local BUILD_DIR="/tmp/9router-build-${TIMESTAMP}"

    # Choose source
    local source_choice
    source_choice=$(select_option "Source code" \
        "Clone từ Git repo ($REPO_URL)" \
        "Dùng thư mục có sẵn (local path)" \
        "Dùng npm package (9router)" \
    )

    case "$source_choice" in
        1)
            log_info "Cloning repo: $REPO_URL..."
            git clone --depth 1 "$REPO_URL" "$BUILD_DIR"
            log_success "Cloned to $BUILD_DIR"
            ;;
        2)
            local local_path
            ask "Local path to source code" "/tmp/9router-deploy" "local_path"
            BUILD_DIR="$local_path"
            log_success "Using local path: $BUILD_DIR"
            ;;
        3)
            # Use simple npm-based Dockerfile
            BUILD_DIR="/tmp/9router-npm-${TIMESTAMP}"
            mkdir -p "$BUILD_DIR"
            cat > "${BUILD_DIR}/Dockerfile" <<'DOCKERFILE'
FROM node:20-alpine

WORKDIR /app

RUN npm install -g 9router

ENV NODE_ENV=production
ENV PORT=20128
ENV HOSTNAME=0.0.0.0

EXPOSE 20128

CMD ["9router"]
DOCKERFILE
            DOCKERFILE_PATH="${BUILD_DIR}/Dockerfile"
            log_success "Created npm-based Dockerfile at $BUILD_DIR"
            ;;
    esac

    # Copy Dockerfile if needed
    if [[ "$source_choice" != "3" ]] && [[ -f "$DOCKERFILE_PATH" ]]; then
        if [[ "$(realpath "$DOCKERFILE_PATH")" != "$(realpath "${BUILD_DIR}/Dockerfile")" ]]; then
            log_info "Copying Dockerfile to build directory..."
            cp "$DOCKERFILE_PATH" "${BUILD_DIR}/Dockerfile"
            log_success "Dockerfile copied"
        fi
    fi

    # Verify Dockerfile exists
    if [[ ! -f "${BUILD_DIR}/Dockerfile" ]]; then
        log_error "Dockerfile not found at ${BUILD_DIR}/Dockerfile"
        exit 1
    fi

    # ─── Build Strategy ──────────────────────────────────────────────────
    log_step "🔨 Build"

    local build_choice
    build_choice=$(select_option "Build strategy" \
        "Cloud Build (build trên GCP, ko cần Docker local)" \
        "Local Docker build + push" \
    )

    case "$build_choice" in
        1)
            log_info "Submitting to Cloud Build..."
            gcloud builds submit "$BUILD_DIR" \
                --tag "$IMAGE_TAG" \
                --project "$PROJECT_ID" \
                --quiet

            # Also tag with timestamp
            log_info "Tagging with timestamp..."
            gcloud artifacts docker tags add "$IMAGE_TAG" "$IMAGE_TAG_VERSIONED" \
                --quiet 2>/dev/null || true

            log_success "Cloud Build complete: $IMAGE_TAG"
            ;;
        2)
            log_info "Building Docker image locally..."
            docker build -t "$IMAGE_TAG" -t "$IMAGE_TAG_VERSIONED" "$BUILD_DIR"
            log_success "Image built: $IMAGE_TAG"

            log_info "Pushing to Artifact Registry..."
            docker push "$IMAGE_TAG"
            docker push "$IMAGE_TAG_VERSIONED"
            log_success "Image pushed: $IMAGE_TAG"
            ;;
    esac

    # ─── Deploy ──────────────────────────────────────────────────────────
    log_step "🚀 Deploy to Cloud Run"

    log_info "Deploying ${SERVICE_NAME}..."

    gcloud run deploy "$SERVICE_NAME" \
        --image "$IMAGE_TAG" \
        --region "$REGION" \
        --project "$PROJECT_ID" \
        --platform managed \
        --port "$PORT" \
        --memory "$MEMORY" \
        --cpu "$CPU" \
        --min-instances "$MIN_INSTANCES" \
        --max-instances "$MAX_INSTANCES" \
        --set-env-vars "NODE_ENV=production,INITIAL_PASSWORD=${INITIAL_PASSWORD},PORT=${PORT}" \
        --allow-unauthenticated \
        --quiet

    log_success "Deployed: $SERVICE_NAME"

    # ─── Get URL ─────────────────────────────────────────────────────────
    log_step "🌐 Service URL"

    local SERVICE_URL
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID" \
        --format 'value(status.url)')

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}✅ Deployment Successful!${NC}                                  ${GREEN}║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}  Service:  ${CYAN}${SERVICE_NAME}${NC}"
    echo -e "${GREEN}║${NC}  Region:   ${CYAN}${REGION}${NC}"
    echo -e "${GREEN}║${NC}  URL:      ${CYAN}${SERVICE_URL}${NC}"
    echo -e "${GREEN}║${NC}  Image:    ${CYAN}${IMAGE_TAG}${NC}"
    echo -e "${GREEN}║${NC}  Password: ${CYAN}${INITIAL_PASSWORD}${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Quick health check
    if ask_yn "Run health check?" "y"; then
        log_info "Testing endpoint..."
        local http_code
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "$SERVICE_URL" 2>/dev/null || echo "000")
        if [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
            log_success "Health check passed! (HTTP $http_code)"
        elif [[ "$http_code" == "000" ]]; then
            log_warn "Timeout — container may be cold-starting. Try again in 10s."
        else
            log_warn "Got HTTP $http_code — service may still be starting."
        fi
    fi

    # Cleanup build dir
    if [[ "$source_choice" == "1" || "$source_choice" == "3" ]]; then
        if ask_yn "Delete build directory ($BUILD_DIR)?" "y"; then
            rm -rf "$BUILD_DIR"
            log_success "Cleaned up: $BUILD_DIR"
        fi
    fi
}

# ============================================================================
# 3. Redeploy (Quick — same image, new revision)
# ============================================================================

quick_redeploy() {
    log_step "⚡ Quick Redeploy (new revision)"

    local IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/docker-repo/${IMAGE_NAME}:latest"

    gcloud run deploy "$SERVICE_NAME" \
        --image "$IMAGE_URI" \
        --region "$REGION" \
        --project "$PROJECT_ID" \
        --platform managed \
        --port "$PORT" \
        --memory "$MEMORY" \
        --cpu "$CPU" \
        --min-instances "$MIN_INSTANCES" \
        --max-instances "$MAX_INSTANCES" \
        --set-env-vars "NODE_ENV=production,INITIAL_PASSWORD=${INITIAL_PASSWORD},PORT=${PORT}" \
        --allow-unauthenticated \
        --quiet

    local SERVICE_URL
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID" \
        --format 'value(status.url)')

    log_success "Redeployed! URL: $SERVICE_URL"
}

# ============================================================================
# 4. Show Status
# ============================================================================

show_status() {
    log_step "📊 Current Status"

    # gcloud auth
    log_info "Active account:"
    gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null

    log_info "Active project:"
    gcloud config get project 2>/dev/null

    echo ""

    # Cloud Run services
    log_info "Cloud Run services in project '$PROJECT_ID':"
    gcloud run services list \
        --project "$PROJECT_ID" \
        --format="table(metadata.name, status.url, status.conditions.status)" \
        2>/dev/null || log_warn "Could not list services"

    echo ""

    # Revisions
    log_info "Latest revisions for '$SERVICE_NAME':"
    gcloud run revisions list \
        --service "$SERVICE_NAME" \
        --region "$REGION" \
        --project "$PROJECT_ID" \
        --format="table(metadata.name, metadata.creationTimestamp, status.conditions[0].status)" \
        --limit 5 \
        2>/dev/null || log_warn "Could not list revisions"

    echo ""

    # VMs (if any)
    log_info "Compute instances:"
    gcloud compute instances list \
        --project "$PROJECT_ID" \
        --format="table(name, zone, status, networkInterfaces[0].accessConfigs[0].natIP)" \
        2>/dev/null || log_warn "No VMs found"
}

# ============================================================================
# 5. Cleanup Resources
# ============================================================================

cleanup_resources() {
    log_step "🧹 Cleanup Resources"

    echo -e "${YELLOW}Select resources to clean up:${NC}"
    echo ""

    # Delete Cloud Run service
    if ask_yn "Delete Cloud Run service '$SERVICE_NAME'?" "n"; then
        log_info "Deleting Cloud Run service..."
        gcloud run services delete "$SERVICE_NAME" \
            --region "$REGION" \
            --project "$PROJECT_ID" \
            --quiet
        log_success "Deleted service: $SERVICE_NAME"
    fi

    # Delete VMs
    local vms
    vms=$(gcloud compute instances list \
        --project "$PROJECT_ID" \
        --format="value(name,zone)" 2>/dev/null || echo "")

    if [[ -n "$vms" ]]; then
        echo ""
        log_info "Found VMs:"
        echo "$vms"
        echo ""

        if ask_yn "Delete ALL VMs in project?" "n"; then
            while IFS=$'\t' read -r vm_name vm_zone; do
                log_info "Deleting VM: $vm_name (zone: $vm_zone)..."
                gcloud compute instances delete "$vm_name" \
                    --zone="$vm_zone" \
                    --project="$PROJECT_ID" \
                    --quiet
                log_success "Deleted VM: $vm_name"
            done <<< "$vms"
        fi
    fi

    # Delete firewall rules
    local fw_rules
    fw_rules=$(gcloud compute firewall-rules list \
        --project "$PROJECT_ID" \
        --format="value(name)" \
        --filter="name~9router OR name~combo" 2>/dev/null || echo "")

    if [[ -n "$fw_rules" ]]; then
        echo ""
        log_info "Found firewall rules:"
        echo "$fw_rules"
        echo ""

        if ask_yn "Delete matching firewall rules?" "n"; then
            while read -r rule_name; do
                log_info "Deleting firewall rule: $rule_name..."
                gcloud compute firewall-rules delete "$rule_name" \
                    --project="$PROJECT_ID" \
                    --quiet
                log_success "Deleted rule: $rule_name"
            done <<< "$fw_rules"
        fi
    fi

    # Delete Artifact Registry images
    if ask_yn "Delete all Docker images in registry?" "n"; then
        log_info "Deleting images..."
        gcloud artifacts docker images delete \
            "${REGION}-docker.pkg.dev/${PROJECT_ID}/docker-repo/${IMAGE_NAME}" \
            --delete-tags \
            --quiet 2>/dev/null || log_warn "No images found or already deleted"
        log_success "Images cleaned up"
    fi

    echo ""
    log_success "✅ Cleanup complete!"
}

# ============================================================================
# 6. Switch GCP Account
# ============================================================================

switch_account() {
    log_step "🔄 Switch GCP Account"

    log_info "Current accounts:"
    gcloud auth list --format="table(account, status)" 2>/dev/null
    echo ""

    local accounts
    accounts=$(gcloud auth list --format="value(account)" 2>/dev/null)
    local account_array=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && account_array+=("$line")
    done <<< "$accounts"

    account_array+=("Login new account")

    local choice
    choice=$(select_option "Select account" "${account_array[@]}")

    if [[ "$choice" -gt 0 && "$choice" -le "${#account_array[@]}" ]]; then
        local selected="${account_array[$((choice - 1))]}"
        if [[ "$selected" == "Login new account" ]]; then
            gcloud auth login
        else
            gcloud config set account "$selected" --quiet
            log_success "Switched to: $selected"
        fi
    fi
}

# ============================================================================
# Main Menu
# ============================================================================

main_menu() {
    print_banner

    # Prerequisite check
    require_cmd "gcloud" "https://cloud.google.com/sdk/docs/install"
    require_cmd "git" "brew install git"

    while true; do
        echo ""
        echo -e "${BOLD}═══ Main Menu ══════════════════════════════${NC}"
        echo ""
        echo -e "  ${BOLD}1)${NC} 🏗️  Setup GCP Project ${DIM}(create project, enable APIs, billing)${NC}"
        echo -e "  ${BOLD}2)${NC} 🚀 Build & Deploy ${DIM}(build Docker, push, deploy Cloud Run)${NC}"
        echo -e "  ${BOLD}3)${NC} ⚡ Full Setup + Deploy ${DIM}(1 + 2 combined)${NC}"
        echo -e "  ${BOLD}4)${NC} 🔄 Quick Redeploy ${DIM}(same image, new revision)${NC}"
        echo -e "  ${BOLD}5)${NC} 📊 Show Status ${DIM}(services, VMs, revisions)${NC}"
        echo -e "  ${BOLD}6)${NC} 🧹 Cleanup ${DIM}(delete services, VMs, images)${NC}"
        echo -e "  ${BOLD}7)${NC} 🔄 Switch GCP Account"
        echo -e "  ${BOLD}8)${NC} ⚡ Deploy with all defaults ${DIM}(no questions, fastest)${NC}"
        echo ""
        echo -e "  ${BOLD}0)${NC} Exit"
        echo ""
        echo -ne "${CYAN}→${NC} Choose (0-8): "
        read -r menu_choice

        case "$menu_choice" in
            1)
                collect_config
                setup_gcp_project
                ;;
            2)
                collect_config
                build_and_deploy
                ;;
            3)
                collect_config
                setup_gcp_project
                build_and_deploy
                ;;
            4)
                collect_config
                quick_redeploy
                ;;
            5)
                collect_config_fast
                show_status
                ;;
            6)
                collect_config
                cleanup_resources
                ;;
            7)
                switch_account
                ;;
            8)
                collect_config_fast
                log_info "Using all defaults — no questions!"
                setup_gcp_project
                build_and_deploy
                ;;
            0|q|exit)
                echo ""
                log_info "Bye! 👋"
                exit 0
                ;;
            *)
                log_error "Invalid option: $menu_choice"
                ;;
        esac

        echo ""
        echo -e "${DIM}──────────────────────────────────────────────${NC}"
        if ! ask_yn "Back to menu?" "y"; then
            log_info "Bye! 👋"
            exit 0
        fi
    done
}

# ============================================================================
# CLI Arguments (for non-interactive usage)
# ============================================================================

# Support: ./deploy.sh --fast  (deploy with all defaults)
# Support: ./deploy.sh --status (show status)
# Support: ./deploy.sh --cleanup (cleanup)

if [[ $# -gt 0 ]]; then
    case "$1" in
        --fast|--auto)
            print_banner
            require_cmd "gcloud" "https://cloud.google.com/sdk/docs/install"
            collect_config_fast
            setup_gcp_project
            build_and_deploy
            exit 0
            ;;
        --deploy)
            print_banner
            require_cmd "gcloud" "https://cloud.google.com/sdk/docs/install"
            collect_config
            build_and_deploy
            exit 0
            ;;
        --status)
            print_banner
            require_cmd "gcloud" "https://cloud.google.com/sdk/docs/install"
            collect_config_fast
            show_status
            exit 0
            ;;
        --setup)
            print_banner
            require_cmd "gcloud" "https://cloud.google.com/sdk/docs/install"
            collect_config
            setup_gcp_project
            exit 0
            ;;
        --cleanup)
            print_banner
            require_cmd "gcloud" "https://cloud.google.com/sdk/docs/install"
            collect_config
            cleanup_resources
            exit 0
            ;;
        --help|-h)
            print_banner
            echo "Usage: ./deploy.sh [OPTION]"
            echo ""
            echo "Options:"
            echo "  (no args)     Interactive menu"
            echo "  --fast        Deploy with all defaults (no questions)"
            echo "  --deploy      Build & deploy (with config questions)"
            echo "  --setup       Setup GCP project only"
            echo "  --status      Show current status"
            echo "  --cleanup     Cleanup resources"
            echo "  --help        Show this help"
            echo ""
            echo "Environment overrides:"
            echo "  PROJECT_ID=myproject SERVICE_NAME=myapp ./deploy.sh --fast"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1 (use --help)"
            exit 1
            ;;
    esac
fi

# Default: interactive menu
main_menu
