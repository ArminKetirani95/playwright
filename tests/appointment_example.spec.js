// Import modules
import { test, expect } from '@playwright/test';
import { LOGIN } from '../lib/functions.js';
import { CONST_ID_BUTTON_MAKE, CONST_ID_DROPDOWN_FACILITY, CONST_ID_DATE_VISITDATE, CONST_ID_CHECKBOX_HOSPITALREADMISSION,
  CONST_ID_HEADER_MAKEAPPOINTMENT, CONST_ID_TEXTFIELD_COMMENT, CONST_ID_BUTTON_BOOKAPPOINTMENT, CONST_ID_TEXT_COMMENT,
  CONST_ID_HEADER_APPOINTMENTCONFIRMATION, CONST_DROPDOWN_FACILITY_OPTIONS, CONST_RADIOBUTTON_PROGRAM_OPTIONS, 
  CONST_ID_TEXT_FACILITY, CONST_ID_TEXT_HOSPITAL_READMISSION, CONST_ID_TEXT_PROGRAM, CONST_ID_TEXT_VISIT_DATE, 
  CONST_LOGIN_USERNAME, CONST_LOGIN_PASSWORD } from '../lib/constants.js';

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
    // ----- Step 1: Enter credentials and login -----
    // Click on the "Make Appointment" button
    await page.click(CONST_ID_BUTTON_MAKE);

    // Type the username and password and then click the "Login" button
    await LOGIN(page, CONST_LOGIN_USERNAME, CONST_LOGIN_PASSWORD);

    // Validate that the "Make Appointment" header is visible on the page
    expect(await page.isVisible(CONST_ID_HEADER_MAKEAPPOINTMENT)).toBeTruthy();

    // Take a screenshot
    await page.screenshot({ path: 'test-results/screenshot_make_appointment_baisc.png', fullPage: true });
  });

  // Test function
  test('Make appointment - Advanced', async ({ page }) => {
    // ----- Step 1: Enter credentials and login -----
    // Click on the "Make Appointment" button
    await page.click(CONST_ID_BUTTON_MAKE);

    // Type the username and password and then click the "Login" button
    await LOGIN(page, CONST_LOGIN_USERNAME, CONST_LOGIN_PASSWORD);

    // Validate that the "Make Appointment" header is visible on the page
    expect(await page.isVisible(CONST_ID_HEADER_MAKEAPPOINTMENT)).toBeTruthy();
    
    // Take a screenshot
    await page.screenshot({ path: 'test-results/screenshot_make_appointment_advanced.png', fullPage: true });

    // ----- Step 2: Fill out the relevant fields and book appointment -----
    // Select a random "Facility" option from the dropdown
    const randomFacility = CONST_DROPDOWN_FACILITY_OPTIONS[Math.floor(Math.random() * CONST_DROPDOWN_FACILITY_OPTIONS.length)];
    await page.selectOption(CONST_ID_DROPDOWN_FACILITY, { label: randomFacility });

    // Check the checkbox "Apply for hospotal readmission"
    await page.check(CONST_ID_CHECKBOX_HOSPITALREADMISSION);

    // Select a random "Healthcare Program"
    const randomRadioButton = CONST_RADIOBUTTON_PROGRAM_OPTIONS[Math.floor(Math.random() * CONST_RADIOBUTTON_PROGRAM_OPTIONS.length)];
    await page.click(randomRadioButton);
    const expectedProgram = await page.getAttribute(randomRadioButton, 'value'); // Extract the value of the selected radio button

    // Fill out the date field with today's date
    const formattedDate = new Date().toLocaleDateString('en-GB'); // Get today's date and format it as dd/mm/yyyy
    await page.fill(CONST_ID_DATE_VISITDATE, formattedDate);
    await page.press(CONST_ID_DATE_VISITDATE, 'Enter');

    // Fill out the comment section with the message 'This is a test'
    const textComment = "This is a test";
    await page.fill(CONST_ID_TEXTFIELD_COMMENT, textComment);

    // Click on the "Book Appointment" button
    await page.click(CONST_ID_BUTTON_BOOKAPPOINTMENT);

    // Validate Appointment Confirmation
    expect(await page.isVisible(CONST_ID_HEADER_APPOINTMENTCONFIRMATION)).toBeTruthy();

    // Take a screenshot
    await page.screenshot({ path: 'test-results/screenshot_appointment_confirmation_advanced.png', fullPage: true });

    // ----- Step 3: Validate confirmation details -----
    // Validate Facility
    const displayedFacility = await page.textContent(CONST_ID_TEXT_FACILITY);
    expect(displayedFacility).toBe(randomFacility);
    console.log(`Facility: ${displayedFacility}`);

    // Validate Apply for hospital readmission
    const displayedReadmission = await page.textContent(CONST_ID_TEXT_HOSPITAL_READMISSION);
    const expectedReadmission = 'Yes';
    expect(displayedReadmission).toBe(expectedReadmission);
    console.log(`Hospital Readmission: ${displayedReadmission}`);

    // Validate Healthcare Program
    const displayedProgram = await page.textContent(CONST_ID_TEXT_PROGRAM);
    expect(displayedProgram).toBe(expectedProgram);
    console.log(`Healthcare Program: ${displayedProgram}`);

    // Validate Visit Date
    const displayedVisitDate = await page.textContent(CONST_ID_TEXT_VISIT_DATE);
    expect(displayedVisitDate).toBe(formattedDate);
    console.log(`Visit Date: ${displayedVisitDate}`);

    // Validate Comment
    const displayedComment = await page.textContent(CONST_ID_TEXT_COMMENT);
    expect(displayedComment).toBe(textComment);
    console.log(`Comment: ${displayedComment}`);

    // Take a screenshot
    await page.screenshot({ path: 'test-results/screenshot_validate_details_advanced.png', fullPage: true });
  });
});