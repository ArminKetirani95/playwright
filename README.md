[![Build Status](https://dev.azure.com/sandbox-arke/Playwright/_apis/build/status%2FPlaywrightAzureDevops?branchName=main)](https://dev.azure.com/sandbox-arke/Playwright/_build/latest?definitionId=2&branchName=main)


# 🎭 Playwright

- [About the Project](#about-the-project)
  - [Built With](#built-with)
- [Usage](#usage)
  - [Run tests](#1-run-tests)
  - [Run tests in UI mode](#2-run-tests-in-ui-mode)
  - [Run tests in headed mode](#3-run-tests-in-headed-mode)
  - [Run specific tests](#4-run-specific-tests)
  - [HTML test report](#5-html-test-report)
  - [Allure Report generation](#6-allure-report-generation)

## About the Project
This project is based on Microsoft [Playwright](https://playwright.dev/) 🎭 which enables reliable end-to-end testing for modern web applications. Playwright is a Node.js library that provides a high-level API to automate web browsers, allowing developers to write tests that simulate user interactions and verify that their web applications function correctly.

Top Features:
- **Easy to configure:** Playwright can be easily set up and configured to suit different testing needs.
- **Auto-waits:** Automatically waits for elements to be ready before performing actions, reducing the chances of flaky tests.
- **Video recording:** Records videos of test executions for better debugging and understanding of test failures.
- **Script generation:** Can record user actions on a webpage and generate a Playwright script from them, simplifying test creation.
- **Trace generation:** Generates trace files that provide detailed information about each step of the test execution.
- **Comprehensive reports:** Generates detailed Allure/HTML reports after test execution, with options to capture screenshots, videos, and trace files on failure.

### Built With
- [Playwright](https://playwright.dev): A Node.js library for browser automation.
- [Javascript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/): A strongly typed programming language that builds on JavaScript.

## Usage
This section explains how to run and manage tests using Playwright.

### 1. Run tests
Tests are run in headless mode meaning no browser will open up when running the tests. Results of the tests and test logs will be shown in the terminal.
    ```JS
    npx playwright test
    ```

### 2. Run tests in UI mode
Run your tests with UI Mode for a better developer experience with time travel debugging, watch mode and more.
    ```JS
    npx playwright test --ui
    ```

### 3. Run tests in headed mode
To run your tests in headed mode, use the --headed flag. This will give you the ability to visually see how Playwright interacts with the website.
    ```JS
    npx playwright test --headed
    ```

### 4. Run specific tests
To run a single test file, pass in the name of the test file that you want to run.
    ```JS
    npx playwright test landing-page.spec.ts
    ```

### 5. HTML test rapport
After your test completes, an HTML Reporter will be generated, which shows you a full report of your tests allowing you to filter the report by browsers, passed tests, failed tests, skipped tests and flaky tests. You can click on each test and explore the test's errors as well as each step of the test. By default, the HTML report is opened automatically if some of the tests failed.
    ```JS
    npx playwright show-report
    ```

### 6. Allure Report generation
Allure is a test report tool that shows a detailed representation of what has been tested and how it performed. Here's how to generate and view Allure reports.

#### 6.1. Create the ”allure-results” folder and generate test results
First, create the folder where the Allure results will be stored and run the tests with the Allure reporter enabled.
```JS
npx playwright test --reporter=line,allure-playwright
```

#### 6.2. Convert the test results into an HTML report and delete previous reports
Convert the generated test results into an HTML report. The --clean flag ensures that previous reports are deleted.
```JS
allure generate ./allure-results --clean
```

#### 6.3. Open the allure report
Finally, open the generated Allure report to view the test results.
```JS
allure open ./allure-report
```