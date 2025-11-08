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
