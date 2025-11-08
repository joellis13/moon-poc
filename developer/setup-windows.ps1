# Moon POC - Windows Developer Setup
# Usage: .\setup-windows.ps1 [-ServerIP "192.168.1.100"] [-WithDocker] [-SkipDocker]

param(
    [string]$ServerIP = "",
    [switch]$WithDocker = $false,
    [switch]$SkipDocker = $false,
    [switch]$Help = $false
)

#Requires -Version 5.1

###############################################################################
# Configuration
###############################################################################

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$INSTALL_DIR = "$env:USERPROFILE\.moon-poc"
$LOG_FILE = "$INSTALL_DIR\setup.log"

# Default versions
$JAVA_VERSION = "11"
$GRADLE_VERSION = "8.5"

###############################################################################
# Helper Functions
###############################################################################

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LOG_FILE -Value $logMessage
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Help {
    Write-Host @"
Moon POC Developer Setup (Windows)

Usage: .\setup-windows.ps1 [OPTIONS]

Options:
    -ServerIP <IP>      Server IP address (required)
    -WithDocker         Install Docker Desktop for local Moon
    -SkipDocker         Skip Docker setup (headed browser only)
    -Help               Show this help message

Examples:
    .\setup-windows.ps1 -ServerIP "192.168.1.100"
    .\setup-windows.ps1 -ServerIP "192.168.1.100" -WithDocker
    .\setup-windows.ps1 -ServerIP "192.168.1.100" -SkipDocker

"@
    exit 0
}

###############################################################################
# Pre-flight Checks
###############################################################################

function Test-Prerequisites {
    Write-Log "Running pre-flight checks..."
    
    # Create install directory
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR | Out-Null
    }
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Log "Windows 10 or higher required" "ERROR"
        exit 1
    }
    
    # Check if Hyper-V is available (for Docker)
    if ($WithDocker) {
        $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if ($hyperv -and $hyperv.State -ne "Enabled") {
            Write-Log "Hyper-V is required for Docker Desktop but not enabled" "WARNING"
            Write-Log "Enable it with: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" "WARNING"
        }
    }
    
    Write-Log "Pre-flight checks passed" "SUCCESS"
}

###############################################################################
# Step 1: Install Chocolatey (Package Manager)
###############################################################################

function Install-Chocolatey {
    if (Test-CommandExists choco) {
        Write-Log "Chocolatey already installed: $(choco --version)"
        return
    }
    
    Write-Log "Installing Chocolatey..."
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing Chocolatey requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    Write-Log "Chocolatey installed successfully" "SUCCESS"
}

###############################################################################
# Step 2: Install Java
###############################################################################

function Install-Java {
    if (Test-CommandExists java) {
        Write-Log "Java already installed: $(java -version 2>&1 | Select-String 'version')"
        return
    }
    
    Write-Log "Installing Java $JAVA_VERSION..."
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing Java requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    choco install -y openjdk$JAVA_VERSION
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Log "Java installed successfully" "SUCCESS"
}

###############################################################################
# Step 3: Install Gradle
###############################################################################

function Install-Gradle {
    if (Test-CommandExists gradle) {
        Write-Log "Gradle already installed: $(gradle --version | Select-String 'Gradle')"
        return
    }
    
    Write-Log "Installing Gradle $GRADLE_VERSION..."
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing Gradle requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    choco install -y gradle
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Log "Gradle installed successfully" "SUCCESS"
}

###############################################################################
# Step 4: Install Git
###############################################################################

function Install-Git {
    if (Test-CommandExists git) {
        Write-Log "Git already installed: $(git --version)"
        return
    }
    
    Write-Log "Installing Git..."
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing Git requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    choco install -y git
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Log "Git installed successfully" "SUCCESS"
}

###############################################################################
# Step 5: Install Chrome (for local headed testing)
###############################################################################

function Install-Chrome {
    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
    if (Test-Path $chromePath) {
        Write-Log "Chrome already installed"
        
        # Get Chrome version
        $chromeVersion = (Get-Item $chromePath).VersionInfo.FileVersion
        Write-Log "Chrome version: $chromeVersion"
        return
    }
    
    Write-Log "Installing Google Chrome..."
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing Chrome requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    choco install -y googlechrome
    
    Write-Log "Chrome installed successfully" "SUCCESS"
}

###############################################################################
# Step 6: Install ChromeDriver (for local testing)
###############################################################################

function Install-ChromeDriver {
    if (Test-CommandExists chromedriver) {
        Write-Log "ChromeDriver already installed: $(chromedriver --version 2>&1 | Select-String 'ChromeDriver')"
        return
    }
    
    Write-Log "Installing ChromeDriver..."
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing ChromeDriver requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    choco install -y chromedriver
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Log "ChromeDriver installed successfully" "SUCCESS"
}

###############################################################################
# Step 7: Install Docker Desktop (Optional)
###############################################################################

function Install-DockerDesktop {
    if ($SkipDocker) {
        Write-Log "Skipping Docker installation (--SkipDocker specified)"
        return
    }
    
    if (-not $WithDocker) {
        Write-Log "Skipping Docker installation (use -WithDocker to install)"
        return
    }
    
    if (Test-CommandExists docker) {
        Write-Log "Docker already installed: $(docker --version)"
        return
    }
    
    Write-Log "Installing Docker Desktop..."
    Write-Log "This will require a system restart" "WARNING"
    
    if (-not (Test-Administrator)) {
        Write-Log "Installing Docker requires administrator privileges" "ERROR"
        Write-Log "Please run PowerShell as Administrator and try again" "ERROR"
        exit 1
    }
    
    choco install -y docker-desktop
    
    Write-Log "Docker Desktop installed" "SUCCESS"
    Write-Log "You must restart your computer before using Docker" "WARNING"
}

###############################################################################
# Step 8: Configure Connection to Server
###############################################################################

function Set-ServerConnection {
    param([string]$ServerIP)
    
    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        Write-Log "Server IP not provided" "ERROR"
        Write-Host ""
        Write-Host "Please run again with -ServerIP parameter:"
        Write-Host "  .\setup-windows.ps1 -ServerIP `"192.168.1.100`""
        Write-Host ""
        exit 1
    }
    
    Write-Log "Configuring connection to server: $ServerIP"
    
    # Test connectivity
    Write-Log "Testing connection to Moon server..."
    
    try {
        $response = Invoke-WebRequest -Uri "http://${ServerIP}:30808/status" -UseBasicParsing -TimeoutSec 5
        $status = $response.Content | ConvertFrom-Json
        Write-Log "Moon server is reachable - Free sessions: $($status.total - $status.used)/$($status.total)" "SUCCESS"
    } catch {
        Write-Log "Cannot reach Moon server at $ServerIP" "ERROR"
        Write-Log "Make sure the server setup is complete and accessible from this machine" "ERROR"
        exit 1
    }
    
    # Save connection info
    $connectionInfo = @{
        ServerIP = $ServerIP
        MoonWebDriver = "http://${ServerIP}:30444/wd/hub"
        MoonAPI = "http://${ServerIP}:30808/status"
        MoonUI = "http://${ServerIP}:30900"
        DemoApp = "http://${ServerIP}:30080"
        ConfiguredDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $connectionInfo | ConvertTo-Json | Out-File "$INSTALL_DIR\connection-info.json"
    
    Write-Log "Connection info saved to: $INSTALL_DIR\connection-info.json" "SUCCESS"
    
    return $connectionInfo
}

###############################################################################
# Step 9: Create Test Project
###############################################################################

function New-TestProject {
    param([hashtable]$ConnectionInfo)
    
    Write-Log "Creating sample test project..."
    
    $projectDir = "$INSTALL_DIR\sample-project"
    
    if (Test-Path $projectDir) {
        Write-Log "Sample project already exists at: $projectDir"
        $response = Read-Host "Overwrite? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            return $projectDir
        }
        Remove-Item -Path $projectDir -Recurse -Force
    }
    
    New-Item -ItemType Directory -Path $projectDir | Out-Null
    New-Item -ItemType Directory -Path "$projectDir\src\test\java\stepdefinitions" -Force | Out-Null
    New-Item -ItemType Directory -Path "$projectDir\src\test\resources\features" -Force | Out-Null
    New-Item -ItemType Directory -Path "$projectDir\gradle\wrapper" -Force | Out-Null
    
    # Create build.gradle
    $buildGradleContent = @"
plugins {
    id 'java'
    id 'net.serenity-bdd.serenity-gradle-plugin' version '4.0.30'
}

group = 'com.moonpoc'
version = '1.0-SNAPSHOT'
sourceCompatibility = '11'

repositories {
    mavenCentral()
}

ext {
    serenityVersion = '4.0.30'
    cucumberVersion = '7.14.0'
}

dependencies {
    testImplementation "net.serenity-bdd:serenity-cucumber:`${serenityVersion}"
    testImplementation "net.serenity-bdd:serenity-screenplay:`${serenityVersion}"
    testImplementation "net.serenity-bdd:serenity-screenplay-webdriver:`${serenityVersion}"
    testImplementation "org.junit.platform:junit-platform-launcher:1.10.1"
    testImplementation "org.assertj:assertj-core:3.24.2"
}

test {
    useJUnitPlatform()
    testLogging {
        events "passed", "skipped", "failed"
    }
}

gradle.startParameter.continueOnFailure = true
"@
    
    $buildGradleContent | Out-File -FilePath "$projectDir\build.gradle" -Encoding UTF8
    
    # Create settings.gradle
    $settingsGradleContent = @"
rootProject.name = 'moon-poc-tests'
"@
    
    $settingsGradleContent | Out-File -FilePath "$projectDir\settings.gradle" -Encoding UTF8
    
    # Create serenity.properties
    $serverIP = $ConnectionInfo.ServerIP
    $serenityContent = @"
# Serenity Configuration

# Local Development (headed browser on your machine)
webdriver.driver = chrome
chrome.switches = --start-maximized,--disable-infobars,--disable-extensions
application.url = http://${serverIP}:30080

# Moon Remote (headless, for testing against server)
moon.webdriver.remote.url = http://${serverIP}:30444/wd/hub
moon.webdriver.driver = chrome
moon.application.url = http://${serverIP}:30080

# Moon capabilities (VNC, video recording, etc.)
moon.chrome.capabilities = {
  "moon:options": {
    "enableVNC": true,
    "enableVideo": true,
    "videoName": "`${cucumber.scenario.name}",
    "sessionTimeout": "5m"
  }
}

# Serenity Settings
serenity.project.name = Moon POC Tests
serenity.test.root = stepdefinitions
serenity.take.screenshots = BEFORE_AND_AFTER_EACH_STEP
serenity.verbose.steps = false
serenity.console.colors = true

# Default environment (change to 'moon' for remote testing)
environment = local

# Logging
serenity.logging = VERBOSE
"@
    
    $serenityContent | Out-File -FilePath "$projectDir\serenity.properties" -Encoding UTF8
    
    # Create sample feature file
    $featureContent = @"
Feature: Moon POC Demo

  Scenario: Visit demo application
    Given I open the demo application
    Then I should see the welcome message
"@
    
    $featureContent | Out-File -FilePath "$projectDir\src\test\resources\features\demo.feature" -Encoding UTF8
    
    # Create step definitions
    $stepDefsContent = @"
package stepdefinitions;

import io.cucumber.java.en.Given;
import io.cucumber.java.en.Then;
import net.serenitybdd.core.pages.PageObject;

import static org.assertj.core.api.Assertions.assertThat;

public class DemoSteps extends PageObject {

    @Given("I open the demo application")
    public void openDemoApplication() {
        String baseUrl = System.getProperty("application.url", "http://localhost:30080");
        getDriver().get(baseUrl);
        
        // Log for debugging
        System.out.println("Opened URL: " + baseUrl);
        System.out.println("Page title: " + getDriver().getTitle());
    }

    @Then("I should see the welcome message")
    public void verifyWelcomeMessage() {
        String pageSource = getDriver().getPageSource();
        
        // The nginx demo app contains "Server address"
        assertThat(pageSource)
            .as("Page should contain welcome content")
            .containsIgnoringCase("Server address");
        
        System.out.println("Successfully verified demo app is loaded");
    }
}
"@
    
    $stepDefsContent | Out-File -FilePath "$projectDir\src\test\java\stepdefinitions\DemoSteps.java" -Encoding UTF8
    
    # Create test runner
    $runnerContent = @"
package stepdefinitions;

import io.cucumber.junit.CucumberOptions;
import net.serenitybdd.cucumber.CucumberWithSerenity;
import org.junit.runner.RunWith;

@RunWith(CucumberWithSerenity.class)
@CucumberOptions(
    features = "src/test/resources/features",
    glue = "stepdefinitions",
    plugin = {"pretty", "html:target/cucumber-reports"}
)
public class TestRunner {
}
"@
    
    $runnerContent | Out-File -FilePath "$projectDir\src\test\java\stepdefinitions\TestRunner.java" -Encoding UTF8
    
    # Create gradlew wrapper files (basic versions)
    $gradlewContent = @"
#!/bin/sh
exec gradle `"`$@`"
"@
    $gradlewContent | Out-File -FilePath "$projectDir\gradlew" -Encoding UTF8
    
    $gradlewBatContent = @"
@echo off
gradle %*
"@
    $gradlewBatContent | Out-File -FilePath "$projectDir\gradlew.bat" -Encoding ASCII
    
    # Create README
    $readmeContent = @"
# Moon POC Test Project

## Running Tests

### Local Headed Mode (Chrome opens on your machine)