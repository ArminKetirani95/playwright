// Import modules
import { test, expect } from '@playwright/test';
import { LOGIN } from '../lib/functions.js';
import { CONST_ID_BUTTON_MAKE, CONST_ID_HEADER_MAKEAPPOINTMENT } from '../lib/constants.js';

// Define a test to make an appointment
test.describe(`Demo - Herokuapp`, () => {
  // Before each test, navigate to the web application
  test.beforeEach(async ({ page }, testInfo) => {
      try {
          console.log(`START -> ${testInfo.title}`);
          // Navigate to the web application
          await page.goto(process.env.BASE_URL);
      } catch (error) {
          console.error(error);
          throw error;
      }
  });

  // After each test, log completion status and close web application
  test.afterEach(async ({ page }, testInfo) => {
      try {
          // Closes the browser
          await page.close();
          console.log(`DONE -> ${testInfo.title}`);
          console.log(`Test results -> ${testInfo.status}`);
      } catch (error) {
          console.error(error);
          throw error;
      }
  });

  // Test function
  test('Make appointment - Basic', async ({ page }) => {
    // Click on the "Make Appointment" button
    await page.click(CONST_ID_BUTTON_MAKE);

    // Type the username and password with the values "John Doe" and "ThisIsNotAPassword" and then click the "Login" button
    await LOGIN(page);

    // Validate that the "Make Appointment" header is visible on the page
    expect(await page.isVisible(CONST_ID_HEADER_MAKEAPPOINTMENT)).toBeTruthy();

    // Take a screenshot
    await page.screenshot({ path: 'test-results/screenshot_login_confirmation.png', fullPage: true });
  });
});