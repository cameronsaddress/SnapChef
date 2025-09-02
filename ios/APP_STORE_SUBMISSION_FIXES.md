# App Store Submission Fixes

## ✅ Issue 1: Account Deletion (COMPLETED)
**Guideline 5.1.1(v)** - Apps that support account creation must also offer account deletion.

### What We Fixed:
- Added "Delete Account" button in Profile Settings below Sign Out
- Two-step confirmation process to prevent accidental deletion
- Deletes all CloudKit data (recipes, follows, activities, challenges, user record)
- Clears all local data (UserDefaults, Keychain, cached photos)
- Signs out user after deletion

### Where to Find It:
Profile tab → Below "Sign Out" button → "Delete Account" (red button with trash icon)

---

## ⚠️ Issue 2: In-App Purchase Not Submitted
**Guideline 2.1** - In-app purchase products have not been submitted for review.

### Action Required in App Store Connect:

1. **Go to App Store Connect** → Your App → In-App Purchases
2. **Create/Configure Premium Subscription:**
   - Product ID: `com.snapchef.premium.monthly` (or whatever you used)
   - Type: Auto-Renewable Subscription
   - Reference Name: SnapChef Premium
   - Product Name: SnapChef Premium
   - Price: $4.99/month (or your price)
   
3. **Add Required Screenshot:**
   - Take a screenshot showing the premium upgrade screen
   - Must show: price, features, subscription duration
   - Upload as "Review Screenshot"

4. **Fill in Subscription Details:**
   - Subscription Duration: 1 Month
   - Free Trial: None (or configure if offering)
   - Subscription Group: Create one (e.g., "SnapChef Premium")
   
5. **Add Review Notes:**
   ```
   Test Account (if needed):
   Email: test@example.com
   Password: TestPass123
   
   How to test:
   1. Open app
   2. Go to Profile tab
   3. Tap "Upgrade to Premium"
   4. Complete purchase
   ```

6. **Submit IAP for Review**
7. **Upload New Build** (after IAP is submitted)

---

## ⚠️ Issue 3: Missing Terms of Use Link
**Guideline 3.1.2** - Apps offering subscriptions must include Terms of Use and Privacy Policy links.

### Action Required in App Store Connect:

1. **Host Your Legal Documents:**
   - Upload the Terms of Service and Privacy Policy text I created earlier to your website
   - Example URLs:
     - `https://snapchef.app/terms`
     - `https://snapchef.app/privacy`

2. **In App Store Connect → App Information:**
   - **Privacy Policy URL**: Add your privacy policy URL
   - **Marketing URL**: (optional) Add your website

3. **In App Store Connect → App Version Info:**
   - **Description**: Add this at the bottom:
   ```
   Terms of Use: https://snapchef.app/terms
   Privacy Policy: https://snapchef.app/privacy
   ```

4. **If Using Custom EULA:**
   - Go to App Information → License Agreement
   - Select "Custom License Agreement"
   - Paste your Terms of Service

5. **In Subscription Configuration:**
   Ensure these are visible in the subscription purchase flow:
   - Subscription title: "SnapChef Premium"
   - Duration: "Monthly"
   - Price: "$4.99/month"
   - Terms of Use link
   - Privacy Policy link

---

## 📋 Submission Checklist

### Before Resubmitting:
- [x] Account deletion implemented in app
- [ ] In-App Purchase created and configured
- [ ] Screenshot added to IAP
- [ ] IAP submitted for review
- [ ] Terms of Use hosted online
- [ ] Privacy Policy hosted online
- [ ] URLs added to App Store Connect metadata
- [ ] New build uploaded (1.0.1 or 1.1)

### Reply to App Review:
After completing the above, reply in App Store Connect Resolution Center:

```
Thank you for your review. We have addressed all three issues:

1. ACCOUNT DELETION: 
   - Added in Profile → "Delete Account" button (below Sign Out)
   - Includes two-step confirmation
   - Permanently deletes all user data from CloudKit and device

2. IN-APP PURCHASE:
   - Premium subscription has been configured and submitted for review
   - Screenshot provided showing subscription screen

3. TERMS OF USE:
   - Terms of Use: [your URL]
   - Privacy Policy: [your URL]
   - Links added to app metadata

New build version [1.0.1] has been uploaded with these fixes.
```

---

## 🚀 Quick Web Hosting Options

If you need to quickly host Terms/Privacy pages:

### Option 1: GitHub Pages (Free)
1. Create repo: `snapchef-legal`
2. Add `terms.html` and `privacy.html`
3. Enable GitHub Pages
4. URLs: `https://[username].github.io/snapchef-legal/terms`

### Option 2: Notion (Quick)
1. Create Notion pages with the legal text
2. Publish to web
3. Use Notion public URLs

### Option 3: Simple HTML on Your Server
Create basic HTML files with the Terms and Privacy text I provided earlier.

---

## 📱 Testing Account Deletion

1. Sign in with test account
2. Create some recipes
3. Go to Profile tab
4. Tap "Delete Account" 
5. Confirm twice
6. Verify:
   - User is signed out
   - Can't sign in with deleted account
   - All data is gone from CloudKit dashboard

---

## Notes:
- Account deletion is PERMANENT - make sure to test with a test account
- The delete function removes data from CloudKit but Apple may retain backups
- Consider adding email confirmation for production (not required for submission)