const { chromium } = require('playwright');
const path = require('path');

async function fillRegistrationForm() {
    const screenshotsDir = path.join(__dirname, 'screenshots');
    
    // Launch browser
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        viewport: { width: 1280, height: 800 }
    });
    const page = await context.newPage();

    // Navigate to the registration form
    const formPath = path.join(__dirname, 'registration-form.html');
    await page.goto(`file://${formPath}`);
    
    console.log('Step 1: Filling personal information...');
    
    // Step 1: Personal Information
    await page.fill('#firstName', 'John');
    await page.fill('#lastName', 'Doe');
    await page.fill('#email', 'john.doe@example.com');
    await page.fill('#phone', '+1-555-123-4567');
    
    // Take screenshot of Step 1
    await page.screenshot({ path: path.join(screenshotsDir, 'step1-personal-info.png'), fullPage: true });
    console.log('Screenshot saved: step1-personal-info.png');
    
    // Click Next to go to Step 2 (use more specific selector)
    await page.click('#step1 button.btn-next');
    await page.waitForTimeout(500);
    
    console.log('Step 2: Filling account details...');
    
    // Step 2: Account Details
    await page.fill('#username', 'johndoe123');
    await page.fill('#password', 'SecurePass123!');
    await page.fill('#confirmPassword', 'SecurePass123!');
    await page.selectOption('#securityQuestion', 'pet');
    
    // Take screenshot of Step 2
    await page.screenshot({ path: path.join(screenshotsDir, 'step2-account-details.png'), fullPage: true });
    console.log('Screenshot saved: step2-account-details.png');
    
    // Click Next to go to Step 3 (use more specific selector)
    await page.click('#step2 button.btn-next');
    await page.waitForTimeout(500);
    
    console.log('Step 3: Setting preferences and confirming...');
    
    // Step 3: Preferences & Confirmation
    await page.selectOption('#role', 'developer');
    await page.check('#terms');
    
    // Take screenshot of Step 3
    await page.screenshot({ path: path.join(screenshotsDir, 'step3-preferences.png'), fullPage: true });
    console.log('Screenshot saved: step3-preferences.png');
    
    // Click Complete Registration
    await page.click('#step3 button.btn-submit');
    await page.waitForTimeout(500);
    
    // Take screenshot of success message
    await page.screenshot({ path: path.join(screenshotsDir, 'step4-success.png'), fullPage: true });
    console.log('Screenshot saved: step4-success.png');
    
    console.log('\n✅ Registration form completed successfully!');
    console.log('All screenshots saved to:', screenshotsDir);
    
    await browser.close();
}

fillRegistrationForm().catch(console.error);
