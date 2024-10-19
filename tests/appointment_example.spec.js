// Import modules
import { test, expect } from '@playwright/test'; // Import necessary functions from Playwright Test
import { LOGIN } from '../lib/functions.js';
import { CONST_URL, CONST_ID_BUTTON_MAKE, CONST_ID_HEADER_MAKEAPPOINTMENT, CONST_ID_DROPDOWN_FACILITY, CONST_ID_CHECKBOX_HOSPITALREADMISSION,
  CONST_ID_RADIOBUTTON_MEDICARE, CONST_ID_DATE_VISITDATE, CONST_ID_TEXTFIELD_COMMENT, CONST_ID_BUTTON_BOOKAPPOINTMENT,
  CONST_ID_HEADER_APPOINTMENTCONFIRMATION } from '../lib/constants.js';

// Define a test to make an appointment
test.describe(`Demo - Herokuapp`, () => {
  // Before each test, navigate to the web application
  test.beforeEach(async ({ page }, testInfo) => {
      try {
          console.log(`START -> ${testInfo.title}`);
          // Navigate to the web application
          await page.goto(CONST_URL);
      } catch (error) {
          console.error(error);
          throw error;
      }
  });

  // After each test, log completion status and close web application
  test.afterEach(async ({ page }, testInfo) => {
      try {
          // Closes the browser
          //await browser.close();
          console.log(`DONE -> ${testInfo.title}`);
          console.log(`Test results -> ${testInfo.status}`);
      } catch (error) {
          console.error(error);
          throw error;
      }
  });

  // Test function
  test('Make appointment', async ({ page }) => {
    await test.step('Step 1: Enter credentials and login', async () => {
      // Click on the "Make Appointment" button
      await page.click(CONST_ID_BUTTON_MAKE);

      // Type the username and password with the values "John Doe" and "ThisIsNotAPassword" and then click the "Login" button
      await LOGIN(page);

      // Validate that the "Make Appointment" header is visible on the page
      expect(await page.isVisible(CONST_ID_HEADER_MAKEAPPOINTMENT)).toBeTruthy();
    });

    await test.step('Step 2: Fill out the relevant fields and book appointment', async () => {
      // Select the "Hongkong CURA Healthcare Center" option from the dropdown
      await page.selectOption(CONST_ID_DROPDOWN_FACILITY, { label: 'Hongkong CURA Healthcare Center' });

      // Check the checkbox "Apply for hospotal readmission"
      await page.check(CONST_ID_CHECKBOX_HOSPITALREADMISSION);

      // Click the radio button "Medicaid"
      await page.click(CONST_ID_RADIOBUTTON_MEDICARE);

      // Fill out the date field with today's date
      const formattedDate = new Date().toLocaleDateString('en-GB'); // Get today's date and format it as dd/mm/yyyy
      await page.fill(CONST_ID_DATE_VISITDATE, formattedDate);
      await page.press(CONST_ID_DATE_VISITDATE, 'Enter');

      // Fill out the comment section with the message 'This is a test'
      await page.fill(CONST_ID_TEXTFIELD_COMMENT, 'This is a test');

      // Click on the "Book Appointment" button
      await page.click(CONST_ID_BUTTON_BOOKAPPOINTMENT);

      // Validate Appointment Confirmation
      expect(await page.isVisible(CONST_ID_HEADER_APPOINTMENTCONFIRMATION)).toBeTruthy();
    });
  });
});