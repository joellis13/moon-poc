# Testing Guide

This project uses Serenity BDD with Cucumber for test automation.
Below are the steps to run, write, and debug tests for UI automation using Moon.

## 1. Test Environments

- **Local (headed Chrome)**:  
  Tests run in Chrome on your workstation.
- **Moon (remote headless)**:
  Tests run on the Kubernetes Moon grid (browser in a container).

Switch environment in `serenity.properties`:
```properties
environment = moon  # or 'local'
```

## 2. Running Tests

From the `test-project` directory:

**Local:**
```bash
./gradlew test -Denvironment=local
```

**Moon:**
```bash
./gradlew test -Denvironment=moon
```

## 3. Watching Tests

- **Moon UI:**  
  Open `http://YOUR_SERVER_IP:30900` to see tests live (VNC) and view sessions.
- **Serenity report:**  
  After running, open `target/site/serenity/index.html` for a visual report.

## 4. Writing Tests

### Feature Files

Create `.feature` files in `src/test/resources/features/`:

```gherkin
Feature: Login

  Scenario: User logs in
    Given I am on the login page
    When I enter valid credentials
    Then I am redirected to the dashboard
```

### Step Definitions

Implement steps in `src/test/java/stepdefinitions/` as Java classes.

```java
@Given("I am on the login page")
public void iAmOnLoginPage() {
    getDriver().get("http://localhost:30080/login");
}
```

### Test Runner

The `TestRunner.java` is preconfigured to pick up your features and stepdefs.

## 5. Integration with CI/CD

You can trigger tests in CI using the provided gradle wrapper.

**Example in GitHub Actions:**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '11'
      - run: ./gradlew test -Denvironment=moon
      - uses: actions/upload-artifact@v3
        with:
          name: serenity-reports
          path: target/site/serenity/
```

## 6. Troubleshooting

See [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md).