// @ts-check
const { defineConfig, devices } = require('@playwright/test');
const dotenv = require('dotenv');
const path = require('path');

// Get the directory of this script
const __dirname = path.resolve();

// Determine environment (default: test)
const ENV = process.env.NODE_ENV || 'test';

// Load environment variables from the `.env.<ENV>` file
const envFilePath = path.resolve(__dirname, `environments/.env.${ENV}`);
const result = dotenv.config({ path: envFilePath });

// Log an error if loading the .env file fails
if (result.error) {
  console.error('Fejl ved indlæsning af .env-fil:', result.error);
}

// Log environment variables to ensure they are loaded correctly
console.log(`Miljø: ${ENV}`);
console.log(`baseURL: ${process.env.BASE_URL}`);

// Playwright config to control test execution, retries, parallelism, and timeouts based on the environment.
module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: true,  // Run tests in parallel
  forbidOnly: !!process.env.CI,  // Disable `.only` tests in CI to ensure all tests run
  retries: process.env.CI ? 2 : 0,  // Retry failed tests (2 in CI, 0 in others)
  workers: process.env.CI ? 1 : undefined,  // Use 1 worker in CI, allow multiple workers outside CI
  timeout: 60000,  // Global test timeout

  // Define reporters for the test results
  reporter: [
    ['list'],  // Output a simple list format to the console
    ['html', { outputFolder: 'playwright-report' }],  // Generate an HTML report in the 'playwright-report' folder
    ['allure-playwright'],  // Generate an Allure report for detailed test results
    ['junit', { outputFile: 'test-results/test-results.xml' }]  // JUnit reporter
  ],

  // Global configuration for all projects
  use: {
    baseURL: process.env.BASE_URL,  // Load the base URL from environment variables
    headless: true,  // Run tests in headless mode (without UI)
    trace: 'on-first-retry',  // Collect trace information on the first retry
  },

  // Define projects for running tests on different browsers
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'], headless: true }, },
    //{ name: 'firefox', use: { ...devices['Desktop Firefox'], headless: true }, },
    //{ name: 'webkit', use: { ...devices['Desktop Safari'], headless: true }, },
  ],
});