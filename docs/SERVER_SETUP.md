# Server Setup Guide

## Overview

This guide walks you through setting up a Moon server on Ubuntu for browser test automation.

## Prerequisites

- Ubuntu 20.04 or later (headless is fine)
- 4+ GB RAM (8 GB recommended)
- 20+ GB free disk space
- Sudo access
- Internet connection

## Quick Setup

```bash
git clone https://github.com/joellis13/moon-poc.git
cd moon-poc/server
chmod +x setup.sh
./setup.sh
```

## What Gets Installed

1. **Docker** - Container runtime
2. **K3s** - Lightweight Kubernetes
3. **Docker Registry** - Local registry for browser images (port 30500)
4. **Moon** - Aerokube Moon for browser orchestration (port 30444)
5. **Moon UI** - Web interface for monitoring (port 30900)
6. **Chrome Browser Image** - Custom image with Chrome + ChromeDriver
7. **Demo App** - nginx demo application for testing (port 30080)

## Installation Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/joellis13/moon-poc.git
cd moon-poc/server
```

### Step 2: Run Setup Script

**Basic install:**
```bash
chmod +x setup.sh
./setup.sh
```

**With specific Chrome version:**
```bash
./setup.sh --chrome-version 143.0.7444.60
```

**Update existing installation:**
```bash
./setup.sh --update
```

### Step 3: Wait for Installation

The script will:
- Install Docker and K3s (~5 minutes)
- Deploy Docker Registry (~2 minutes)
- Build Chrome browser image (~10 minutes)
- Deploy Moon and Moon UI (~2 minutes)
- Deploy demo app (~1 minute)

Total time: **15-20 minutes**

## Post-Installation

### Check Service Status

```bash
# All pods
kubectl get pods -A

# Moon specifically
kubectl get pods -n moon

# Moon logs
kubectl logs -n moon -l app=moon
```

### Test Moon API

```bash
curl http://localhost:30808/status
```

Expected output:
```json
{
  "total": 4,
  "used": 0,
  "queued": 0,
  "pending": 0
}
```

### Open Moon UI

Open in browser: `http://YOUR_SERVER_IP:30900`

## Ports Used

| Service | Port | Protocol | Description |
|---------|------|----------|-------------|
| Moon WebDriver | 30444 | HTTP | Selenium WebDriver endpoint |
| Moon API | 30808 | HTTP | Moon status and management |
| Moon UI | 30900 | HTTP | Web interface |
| Docker Registry | 30500 | HTTP | Browser image registry |
| Demo App | 30080 | HTTP | Test application |
| VNC | 30590 | TCP | VNC for browser viewing |

## Firewall Configuration

If developers are on different machines, open these ports:

```bash
sudo ufw allow 30444/tcp  # Moon WebDriver
sudo ufw allow 30808/tcp  # Moon API
sudo ufw allow 30900/tcp  # Moon UI
sudo ufw allow 30080/tcp  # Demo App
sudo ufw allow 30590/tcp  # VNC (optional)
```

## Troubleshooting

### Docker Permission Issues

If you see "permission denied" errors:
```bash
# Log out and back in, or
newgrp docker
```

### K3s Not Starting

```bash
sudo systemctl status k3s
sudo journalctl -u k3s -f
```

### Moon Not Deploying

```bash
# Check pod status
kubectl get pods -n moon

# Check logs
kubectl logs -n moon -l app=moon

# Describe pod for events
kubectl describe pod -n moon -l app=moon
```

## Updating

### Update Chrome Version

```bash
cd moon-poc/server
./setup.sh --chrome-version 143.0.7444.60 --update
```

### Update Moon Version

```bash
./setup.sh --moon-version 2.8.0 --update
```

## Next Steps

1. Share server IP with developers
2. Developers run their setup scripts
3. Run sample tests from test-project
4. Integrate with your existing test suites
