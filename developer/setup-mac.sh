#!/bin/bash
set -e

# Moon POC - Mac/Linux Developer Setup
# Usage: ./setup-mac.sh --server-ip 192.168.1.100 [--with-docker]

###############################################################################
# Configuration
###############################################################################

SCRIPT_DIR="$(cd "".dirname("${BASH_SOURCE[0]}")."" && pwd)"
INSTALL_DIR="$HOME/.moon-poc"
LOG_FILE="$INSTALL_DIR/setup.log"

SERVER_IP=""
WITH_DOCKER=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# Helper Functions
###############################################################################

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

check_command() {
    command -v $1 &> /dev/null
}

###############################################################################
# Parse Arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;; 
        --with-docker)
            WITH_DOCKER=true
            shift
            ;;  
        -h|--help)
            cat << EOF
Moon POC Developer Setup (Mac/Linux)

Usage: ./setup-mac.sh [OPTIONS]

Options:
    --server-ip IP      Server IP address (required)
    --with-docker       Install Docker for local Moon
    -h, --help          Show this help

Examples:
    ./setup-mac.sh --server-ip 192.168.1.100
    ./setup-mac.sh --server-ip 192.168.1.100 --with-docker
EOF
            exit 0
            ;; 
        *)
            log_error "Unknown option: $1"
            exit 1
            ;; 
    esac
done

if [[ -z "$SERVER_IP" ]]; then
    log_error "Server IP is required. Use --server-ip"
    exit 1
fi

###############################################################################
# Pre-flight Checks
###############################################################################

preflight_checks() {
    log "Running pre-flight checks..."
    mkdir -p "$INSTALL_DIR"
    log "Pre-flight checks passed"
}

###############################################################################
# Install Homebrew (Mac) or check apt (Linux)
###############################################################################

install_package_manager() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! check_command brew; then
            log "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
            log_info "Homebrew already installed"
        fi
    else
        log_info "Using apt package manager"
    fi
}

###############################################################################
# Install Java
###############################################################################

install_java() {
    if check_command java; then
        log_info "Java already installed: $(java -version 2>&1 | head -1)"
        return
    fi
    
    log "Installing Java 11..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install openjdk@11
    else
        sudo apt-get update
        sudo apt-get install -y openjdk-11-jdk
    fi
    
    log "Java installed successfully"
}

###############################################################################
# Install Gradle
###############################################################################

install_gradle() {
    if check_command gradle; then
        log_info "Gradle already installed: $(gradle --version | grep Gradle)"
        return
    fi
    
    log "Installing Gradle..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gradle
    else
        sudo apt-get install -y gradle
    fi
    
    log "Gradle installed successfully"
}

###############################################################################
# Install Git
###############################################################################

install_git() {
    if check_command git; then
        log_info "Git already installed: $(git --version)"
        return
    fi
    
    log "Installing Git..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    else
        sudo apt-get install -y git
    fi
    
    log "Git installed successfully"
}

###############################################################################
# Install Chrome
###############################################################################

install_chrome() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ -d "/Applications/Google Chrome.app" ]]; then
            log_info "Chrome already installed"
            return
        fi
        log "Installing Chrome..."
        brew install --cask google-chrome
    else
        if check_command google-chrome; then
            log_info "Chrome already installed"
            return
        fi
        log "Installing Chrome..."
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
        sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
        sudo apt-get update
        sudo apt-get install -y google-chrome-stable
    fi
    
    log "Chrome installed successfully"
}

###############################################################################
# Install ChromeDriver
###############################################################################

install_chromedriver() {
    if check_command chromedriver; then
        log_info "ChromeDriver already installed: $(chromedriver --version 2>&1 | head -1)"
        return
    fi
    
    log "Installing ChromeDriver..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install --cask chromedriver
    else
        sudo apt-get install -y chromium-chromedriver
    fi
    
    log "ChromeDriver installed successfully"
}

###############################################################################
# Install Docker (Optional)
###############################################################################

install_docker() {
    if [[ "$WITH_DOCKER" == false ]]; then
        log_info "Skipping Docker installation"
        return
    fi
    
    if check_command docker; then
        log_info "Docker already installed: $(docker --version)"
        return
    fi
    
    log "Installing Docker..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install --cask docker
    else
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker $USER
    fi
    
    log "Docker installed successfully"
}

###############################################################################
# Test Server Connection
###############################################################################

test_server_connection() {
    log "Testing connection to Moon server at $SERVER_IP..."
    
    if curl -s "http://$SERVER_IP:30808/status" > /dev/null; then
        log "Moon server is reachable!"
    else
        log_error "Cannot reach Moon server at $SERVER_IP"
        exit 1
    fi
    
    # Save connection info
    cat > "$INSTALL_DIR/connection-info.json" <<EOF
{
  "serverIP": "$SERVER_IP",
  "moonWebDriver": "http://$SERVER_IP:30444/wd/hub",
  "moonAPI": "http://$SERVER_IP:30808/status",
  "moonUI": "http://$SERVER_IP:30900",
  "demoApp": "http://$SERVER_IP:30080",
  "configuredDate": "$(date)"
}
EOF
    
    log "Connection info saved to $INSTALL_DIR/connection-info.json"
}

###############################################################################
# Create Test Project
###############################################################################

create_test_project() {
    log "Creating sample test project..."
    
    PROJECT_DIR="$INSTALL_DIR/sample-project"
    
    if [[ -d "$PROJECT_DIR" ]]; then
        log_warning "Sample project already exists"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
        rm -rf "$PROJECT_DIR"
    fi
    
    mkdir -p "$PROJECT_DIR/src/test/java/stepdefinitions"
    mkdir -p "$PROJECT_DIR/src/test/resources/features"
    
    log "Sample project created at: $PROJECT_DIR"
    log "See the test-project/ directory in the repo for full project structure"
}

###############################################################################
# Summary
###############################################################################

print_summary() {
    cat << EOF

${GREEN}═══════════════════════════════════════════════════════════════════${NC}
${GREEN}          Moon POC Developer Setup Complete (Mac/Linux)            ${NC}
${GREEN}═══════════════════════════════════════════════════════════════════${NC}

${BLUE}Server Connection:${NC}
  ├─ Server IP:          $SERVER_IP
  ├─ Moon WebDriver:     http://$SERVER_IP:30444/wd/hub
  ├─ Moon UI:            http://$SERVER_IP:30900
  └─ Demo App:           http://$SERVER_IP:30080

${BLUE}Installed Tools:${NC}
EOF
    check_command java && echo "  ├─ Java:     $(java -version 2>&1 | head -1)"
    check_command gradle && echo "  ├─ Gradle:   $(gradle --version | grep Gradle)"
    check_command git && echo "  ├─ Git:      $(git --version)"
    check_command docker && echo "  └─ Docker:   $(docker --version)"
    
    cat << EOF

${BLUE}Next Steps:${NC}
  1. Clone the test project from the repo
  2. Open Moon UI: http://$SERVER_IP:30900
  3. Run tests locally or against Moon server

${BLUE}Configuration:${NC}
  ├─ Install Dir:        $INSTALL_DIR
  └─ Connection Info:    $INSTALL_DIR/connection-info.json

${GREEN}═══════════════════════════════════════════════════════════════════${NC}

EOF
}

###############################################################################
# Main Execution
###############################################################################

main() {
    log "Moon POC Developer Setup (Mac/Linux) - Starting..."
    
    preflight_checks
    install_package_manager
    install_java
    install_gradle
    install_git
    install_chrome
    install_chromedriver
    install_docker
    test_server_connection
    create_test_project
    print_summary
    
    log "Setup complete!"
}

main "$@"