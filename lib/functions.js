/*
This file contains all functions used in the project.
*/
import { CONST_LOGIN_USERNAME, CONST_LOGIN_PASSWORD, CONST_ID_TEXTFIELD_USERNAME,
    CONST_ID_TEXTFIELD_PASSWORD, CONST_ID_BUTTON_LOGIN } from '../lib/constants.js';

/**
 * Logs into the application with the given username and password.
 * 
 * @param {object} page - Playwright page object.
 * @param {string} username - User's login username.
 * @param {string} password - User's login password.
 */
export async function LOGIN(page, username, password) {
    try {
        // Type the username
        await page.fill(CONST_ID_TEXTFIELD_USERNAME, username);
        
        // Type the password
        await page.fill(CONST_ID_TEXTFIELD_PASSWORD, password);
        
        // Click the login button
        await page.click(CONST_ID_BUTTON_LOGIN);

    } catch (error) {
        throw new Error(`Login error: ${error.message}`);
    }
}