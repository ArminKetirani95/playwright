/*
This file contains all functions used in the project.
*/
import { CONST_LOGIN_USERNAME, CONST_LOGIN_PASSWORD, CONST_ID_TEXTFIELD_USERNAME,
    CONST_ID_TEXTFIELD_PASSWORD, CONST_ID_BUTTON_LOGIN } from '../lib/constants.js';

/**
 * Logs into the application with the specified username and password.
 * 
 * @param {object} page - Playwright page object.
 */
export async function LOGIN(page) {
    try {
        // Type the username
        await page.fill(CONST_ID_TEXTFIELD_USERNAME, CONST_LOGIN_USERNAME);
        
        // Type the password
        await page.fill(CONST_ID_TEXTFIELD_PASSWORD, CONST_LOGIN_PASSWORD);
        
        // Click the login button
        await page.click(CONST_ID_BUTTON_LOGIN);

        console.log('User logged in successfully.');
    } catch (error) {
        throw new Error(`Login error: ${error.message}`);
    }
}