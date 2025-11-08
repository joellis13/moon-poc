#!/bin/bash
set -e

# Moon POC - Server Setup Script
# Usage: ./setup.sh [--chrome-version 142.0.7444.60] [--update]

###############################################################################
# Configuration
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/moon-poc-install"
LOG_FILE="$INSTALL_DIR/setup.log"

# Default versions (can be overridden)
CHROME_VERSION="${CHROME_VERSION:-142.0.7444.60}"
MOON_VERSION="${MOON_VERSION:-2.7.8}"
SELENIUM_VERSION="${SELENIUM_VERSION:-4.25.0}"
UPDATE_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

get_server_ip() {
    hostname -I | awk '{print $1}'
}

###############################################################################
# Parse Arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --chrome-version)
            CHROME_VERSION="$2"
            shift 2
            ;;
        --moon-version)
            MOON_VERSION="$2"
            shift 2
            ;;
        --update)
            UPDATE_MODE=true
            shift
            ;;
        -h|--help)
            cat << EOF
Moon POC Server Setup Script

Usage: ./setup.sh [OPTIONS]

Options:
    --chrome-version VERSION    Chrome version to install (default: 142.0.7444.60)
    --moon-version VERSION      Moon version to install (default: 2.7.8)
    --update                    Update existing installation
    -h, --help                  Show this help message

Examples:
    ./setup.sh                                    # Fresh install with defaults
    ./setup.sh --chrome-version 143.0.7444.60    # Install with Chrome 143
    ./setup.sh --update                           # Update existing install

EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

###############################################################################
# Pre-flight Checks
###############################################################################

preflight_checks() {
    log "Running pre-flight checks..."
    
    mkdir -p "$INSTALL_DIR"
    
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
    
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_warning "This script is designed for Ubuntu. Proceed with caution."
    fi
    
    available_space=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 10 ]]; then
        log_error "Insufficient disk space. Need at least 10GB, have ${available_space}GB"
        exit 1
    fi
    
    log "Pre-flight checks passed"
}

###############################################################################
# Step 1: Docker Installation
###############################################################################

install_docker() {
    if check_command docker; then
        log_info "Docker already installed: $(docker --version)"
        
        if ! groups | grep -q docker; then
            log "Adding user to docker group..."
            sudo usermod -aG docker $USER
            log_warning "User added to docker group. You may need to log out and back in."
        fi
        return 0
    fi
    
    log "Installing Docker..."
    
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo usermod -aG docker $USER
    
    sudo mkdir -p /etc/docker
    SERVER_IP=$(get_server_ip)
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "insecure-registries": ["$SERVER_IP:30500", "localhost:30500"]
}
EOF
    
    sudo systemctl restart docker
    
    log "Docker installed successfully"
    log_warning "You need to log out and back in for docker group changes to take effect"
}

###############################################################################
# Step 2: K3s Installation
###############################################################################

install_k3s() {
    if check_command kubectl && systemctl is-active --quiet k3s; then
        log_info "K3s already installed"
        return 0
    fi
    
    log "Installing K3s..."
    
    curl -sfL https://get.k3s.io | sh -
    
    sleep 10
    
    sudo chmod 644 /etc/rancher/k3s/k3s.yaml
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
    
    kubectl get nodes
    
    log "K3s installed successfully"
}

###############################################################################
# Step 3: Docker Registry
###############################################################################

deploy_registry() {
    log "Deploying Docker Registry..."
    
    mkdir -p "$INSTALL_DIR/registry-data"
    
    SERVER_IP=$(get_server_ip)
    
    cat <<EOF > "$INSTALL_DIR/registry-deployment.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: registry
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: registry-pv
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "$INSTALL_DIR/registry-data"
  persistentVolumeReclaimPolicy: Retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: registry
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-registry
  template:
    metadata:
      labels:
        app: docker-registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        env:
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
      volumes:
      - name: registry-storage
        persistentVolumeClaim:
          claimName: registry-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: docker-registry
  namespace: registry
spec:
  selector:
    app: docker-registry
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 30500
EOF
    
    kubectl apply -f "$INSTALL_DIR/registry-deployment.yaml"
    
    kubectl wait --for=condition=ready pod -l app=docker-registry -n registry --timeout=120s
    
    sleep 5
    if curl -s http://localhost:30500/v2/_catalog > /dev/null; then
        log "Docker Registry deployed successfully at $SERVER_IP:30500"
    else
        log_error "Registry deployment failed"
        exit 1
    fi
}

###############################################################################
# Step 4: Build Chrome Image
###############################################################################

build_chrome_image() {
    log "Building Chrome $CHROME_VERSION image..."
    
    SERVER_IP=$(get_server_ip)
    IMAGE_TAG="$SERVER_IP:30500/moon-browsers/chrome:$CHROME_VERSION"
    
    if docker images | grep -q "$IMAGE_TAG"; then
        if [[ "$UPDATE_MODE" == false ]]; then
            log_info "Chrome image already exists: $IMAGE_TAG"
            read -p "Rebuild anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return 0
            fi
        fi
    fi
    
    mkdir -p "$INSTALL_DIR/browser-images"
    cd "$INSTALL_DIR/browser-images"
    
    cat <<'DOCKERFILE_EOF' > Dockerfile.chrome
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    wget curl unzip gnupg ca-certificates \
    fonts-liberation libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libatspi2.0-0 libcups2 libdbus-1-3 \
    libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 \
    libwayland-client0 libxcomposite1 libxdamage1 \
    libxfixes3 libxkbcommon0 libxrandr2 xdg-utils \
    libu2f-udev libvulkan1 supervisor x11vnc xvfb \
    fluxbox openjdk-11-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ARG CHROME_VERSION
RUN wget -q "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip" -O /tmp/chrome.zip \
    && unzip /tmp/chrome.zip -d /opt/ \
    && rm /tmp/chrome.zip \
    && ln -s /opt/chrome-linux64/chrome /usr/bin/google-chrome \
    && ln -s /opt/chrome-linux64/chrome /usr/bin/chrome

RUN wget -q "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip" -O /tmp/chromedriver.zip \
    && unzip /tmp/chromedriver.zip -d /opt/ \
    && rm /tmp/chromedriver.zip \
    && chmod +x /opt/chromedriver-linux64/chromedriver \
    && ln -s /opt/chromedriver-linux64/chromedriver /usr/bin/chromedriver

ARG SELENIUM_VERSION
RUN wget -q "https://github.com/SeleniumHQ/selenium/releases/download/selenium-${SELENIUM_VERSION}/selenium-server-${SELENIUM_VERSION}.jar" \
    -O /opt/selenium-server.jar

RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

EXPOSE 4444 5900

LABEL browser=chrome
LABEL version=${CHROME_VERSION}

ENV DISPLAY=:99
ENV SCREEN_WIDTH=1920
ENV SCREEN_HEIGHT=1080
ENV SCREEN_DEPTH=24

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
DOCKERFILE_EOF
    
    cat <<'SUPERVISORD_EOF' > supervisord.conf
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
loglevel=info

[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/xvfb.log
stderr_logfile=/var/log/supervisor/xvfb_err.log
priority=1

[program:fluxbox]
command=/usr/bin/fluxbox -display :99
autostart=true
autorestart=true
environment=DISPLAY=":99"
stdout_logfile=/var/log/supervisor/fluxbox.log
stderr_logfile=/var/log/supervisor/fluxbox_err.log
priority=2

[program:x11vnc]
command=/usr/bin/x11vnc -display :99 -forever -shared -rfbport 5900 -passwd selenoid
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/x11vnc.log
stderr_logfile=/var/log/supervisor/x11vnc_err.log
priority=3

[program:selenium]
command=java -jar /opt/selenium-server.jar standalone --port 4444 --host 0.0.0.0 --max-sessions 1
autostart=true
autorestart=true
environment=DISPLAY=":99"
stdout_logfile=/var/log/supervisor/selenium.log
stderr_logfile=/var/log/supervisor/selenium_err.log
priority=4
SUPERVISORD_EOF
    
    log "Building Chrome image (this may take 5-10 minutes)..."
    docker build \
        --build-arg CHROME_VERSION="$CHROME_VERSION" \
        --build-arg SELENIUM_VERSION="$SELENIUM_VERSION" \
        -t "$IMAGE_TAG" \
        -f Dockerfile.chrome \
        . 2>&1 | tee -a "$LOG_FILE"
    
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "Chrome image build failed"
        exit 1
    fi
    
    log "Pushing image to registry..."
    docker push "$IMAGE_TAG"
    
    if curl -s "http://localhost:30500/v2/moon-browsers/chrome/tags/list" | grep -q "$CHROME_VERSION"; then
        log "Chrome $CHROME_VERSION image built and pushed successfully"
    else
        log_error "Failed to verify Chrome image in registry"
        exit 1
    fi
}

###############################################################################
# Step 5: Deploy Moon
###############################################################################

deploy_moon() {
    log "Deploying Moon..."
    
    SERVER_IP=$(get_server_ip)
    
    cat <<EOF > "$INSTALL_DIR/moon-deployment.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: moon
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: moon-config
  namespace: moon
data:
  browsers.json: |
    {
      "chrome": {
        "default": "$CHROME_VERSION",
        "versions": {
          "$CHROME_VERSION": {
            "image": "$SERVER_IP:30500/moon-browsers/chrome:$CHROME_VERSION",
            "port": "4444",
            "path": "/",
            "resources": {
              "requests": {
                "memory": "512Mi",
                "cpu": "500m"
              },
              "limits": {
                "memory": "1Gi",
                "cpu": "1000m"
              }
            },
            "env": {
              "ENABLE_VNC": "true"
            }
          }
        }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moon
  namespace: moon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moon
  template:
    metadata:
      labels:
        app: moon
    spec:
      containers:
      - name: moon
        image: aerokube/moon:$MOON_VERSION
        ports:
        - containerPort: 4444
          name: webdriver
        - containerPort: 8080
          name: moon-api
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        env:
        - name: MOON_KUBERNETES_ENABLED
          value: "true"
        - name: MOON_CONTAINER_RUNTIME
          value: "kubernetes"
        - name: MOON_SESSION_TIMEOUT
          value: "5m"
        - name: MOON_SERVICE_STARTUP_TIMEOUT
          value: "30s"
        volumeMounts:
        - name: config
          mountPath: /moon/browsers.json
          subPath: browsers.json
      volumes:
      - name: config
        configMap:
          name: moon-config
---
apiVersion: v1
kind: Service
metadata:
  name: moon
  namespace: moon
spec:
  selector:
    app: moon
  type: NodePort
  ports:
  - name: webdriver
    port: 4444
    targetPort: 4444
    nodePort: 30444
  - name: moon-api
    port: 8080
    targetPort: 8080
    nodePort: 30808
  - name: vnc
    port: 5900
    targetPort: 5900
    nodePort: 30590
EOF
    
    kubectl apply -f "$INSTALL_DIR/moon-deployment.yaml"
    kubectl wait --for=condition=ready pod -l app=moon -n moon --timeout=120s
    
    sleep 5
    if curl -s http://localhost:30808/status > /dev/null; then
        log "Moon deployed successfully"
    else
        log_error "Moon deployment failed"
        exit 1
    fi
}

###############################################################################
# Step 6: Deploy Moon UI
###############################################################################

deploy_moon_ui() {
    log "Deploying Moon UI..."
    
    cat <<EOF > "$INSTALL_DIR/moon-ui-deployment.yaml"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: moon-ui
  namespace: moon
spec:
  replicas: 1
  selector:
    matchLabels:
      app: moon-ui
  template:
    metadata:
      labels:
        app: moon-ui
    spec:
      containers:
      - name: moon-ui
        image: aerokube/moon-ui:latest
        ports:
        - containerPort: 8080
        env:
        - name: MOON_URL
          value: "http://moon:8080"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: moon-ui
  namespace: moon
spec:
  selector:
    app: moon-ui
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30900
EOF
    
    kubectl apply -f "$INSTALL_DIR/moon-ui-deployment.yaml"
    kubectl wait --for=condition=ready pod -l app=moon-ui -n moon --timeout=120s
    
    log "Moon UI deployed successfully"
}

###############################################################################
# Step 7: Deploy Demo App
###############################################################################

deploy_demo_app() {
    log "Deploying demo application..."
    
    cat <<EOF > "$INSTALL_DIR/demo-app-deployment.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: demo-app
        image: nginxdemos/hello:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: demo-app
spec:
  selector:
    app: demo-app
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
    
    kubectl apply -f "$INSTALL_DIR/demo-app-deployment.yaml"
    kubectl wait --for=condition=ready pod -l app=demo-app -n demo-app --timeout=120s
    
    log "Demo app deployed successfully"
}

###############################################################################
# Verification
###############################################################################

verify_installation() {
    log "Verifying installation..."
    
    local all_good=true
    SERVER_IP=$(get_server_ip)
    
    if ! kubectl get nodes | grep -q Ready; then
        log_error "K3s nodes not ready"
        all_good=false
    fi
    
    if ! curl -s http://localhost:30500/v2/_catalog > /dev/null; then
        log_error "Registry not responding"
        all_good=false
    fi
    
    if ! curl -s http://localhost:30808/status | grep -q '"total":4'; then
        log_error "Moon not responding correctly"
        all_good=false
    fi
    
    if ! curl -s http://localhost:30900 > /dev/null; then
        log_error "Moon UI not responding"
        all_good=false
    fi
    
    if ! curl -s http://localhost:30080 > /dev/null; then
        log_error "Demo app not responding"
        all_good=false
    fi
    
    if [[ "$all_good" == true ]]; then
        log "All services verified successfully!"
        print_summary
    else
        log_error "Some services failed verification. Check logs above."
        exit 1
    fi
}

print_summary() {
    SERVER_IP=$(get_server_ip)
    
    cat << EOF

${GREEN}═══════════════════════════════════════════════════════════════════${NC}
${GREEN}                    Moon POC Setup Complete!                        ${NC}
${GREEN}═══════════════════════════════════════════════════════════════════${NC}

${BLUE}Server IP:${NC} $SERVER_IP

${BLUE}Services:${NC}
  ├─ Moon WebDriver:     http://$SERVER_IP:30444/wd/hub
  ├─ Moon API:           http://$SERVER_IP:30808/status
  ├─ Moon UI:            http://$SERVER_IP:30900
  ├─ Docker Registry:    http://$SERVER_IP:30500
  └─ Demo Application:   http://$SERVER_IP:30080

${BLUE}Chrome Version:${NC} $CHROME_VERSION
${BLUE}Moon Version:${NC} $MOON_VERSION

${BLUE}Configuration:${NC}
  ├─ Install Directory:  $INSTALL_DIR
  ├─ Log File:          $LOG_FILE
  └─ Browser Image:     $SERVER_IP:30500/moon-browsers/chrome:$CHROME_VERSION

${BLUE}Quick Commands:${NC}
  kubectl get pods -A
  kubectl logs -n moon -l app=moon
  curl http://localhost:30808/status

${BLUE}Next Steps:${NC}
  1. Open Moon UI: http://$SERVER_IP:30900
  2. Configure developers with server IP: $SERVER_IP
  3. Check docs/ for developer setup

${YELLOW}Note:${NC} If you see permission errors with docker, log out and back in.

${GREEN}═══════════════════════════════════════════════════════════════════${NC}

EOF

    cat > "$INSTALL_DIR/connection-info.txt" << INFO_EOF
Moon POC Connection Information
Generated: $(date)

Server IP: $SERVER_IP
Chrome Version: $CHROME_VERSION
Moon Version: $MOON_VERSION

Services:
- Moon WebDriver: http://$SERVER_IP:30444/wd/hub
- Moon API: http://$SERVER_IP:30808/status
- Moon UI: http://$SERVER_IP:30900
- Docker Registry: http://$SERVER_IP:30500
- Demo App: http://$SERVER_IP:30080

For developer setup, use these connection details in serenity.properties:
moon.webdriver.remote.url = http://$SERVER_IP:30444/wd/hub
moon.application.url = http://$SERVER_IP:30080
INFO_EOF
    
    log "Connection info saved to: $INSTALL_DIR/connection-info.txt"
}

###############################################################################
# Main Execution
###############################################################################

main() {
    log "Moon POC Server Setup - Starting..."
    log "Chrome Version: $CHROME_VERSION"
    log "Moon Version: $MOON_VERSION"
    log "Update Mode: $UPDATE_MODE"
    
    preflight_checks
    install_docker
    install_k3s
    deploy_registry
    build_chrome_image
    deploy_moon
    deploy_moon_ui
    deploy_demo_app
    verify_installation
    
    log "Setup complete!"
}

main "$@"