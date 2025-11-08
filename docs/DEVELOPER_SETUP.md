# Developer Setup Guide

This guide shows how to set up your local environment to develop, run, and debug UI tests with Moon.

## 1. Prerequisites

- **Java 11+**
- **Gradle 7+** (or use provided wrapper)
- **Git**
- **Chrome browser**
- (Optional) Docker Desktop (for local browser grid)

## 2. Clone the Repository

```bash
git clone -b add_setup_scripts https://github.com/joellis13/moon-poc.git
cd moon-poc
```

## 3. Run the Developer Setup Script

- **Windows:**  
  Open PowerShell as Administrator and run:
  ```powershell
  cd developer
  .\setup-windows.ps1 -ServerIP "YOUR_SERVER_IP"
  ```

- **Mac/Linux:**
  ```bash
  cd developer
  chmod +x setup-mac.sh
  ./setup-mac.sh --server-ip YOUR_SERVER_IP
  ```

Replace `YOUR_SERVER_IP` with the actual server IP provided by QA/admin.

## 4. Configure Serenity Project

- The developer script will generate `serenity.properties` and configure remote (Moon) and local (headed) testing.
- If you want to test locally only (with Chrome), set:
  ```
environment = local
  ```
- To use Moon:
  ```
environment = moon
  ```

## 5. Running Tests

From the root or `test-project` directory:

- **Locally (headed):**
  ```bash
  ./gradlew test -Denvironment=local
  ```

- **Remotely (Moon grid):**
  ```bash
  ./gradlew test -Denvironment=moon
  ```

## 6. Troubleshooting

See [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common fixes.

## 7. Optional: Local Moon Instance (Docker Compose)

If you want to run your own Moon in Docker:

```bash
cd developer/config
docker compose up -d
```

Then set
```
moon.webdriver.remote.url = http://localhost:30444/wd/hub
```
in `serenity.properties`.

---

If you have any issues, reach out to the server admin or check the Troubleshooting guide.
