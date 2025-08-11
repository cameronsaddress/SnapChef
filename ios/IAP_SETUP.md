# In-App Purchase Setup Guide

## App Store Connect Configuration

### 1. Create App ID
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to "My Apps"
3. Create or select your app
4. Go to "App Information" → "General"
5. Note your Bundle ID: `com.snapchefapp.app`

### 2. Configure In-App Purchases
1. In App Store Connect, go to your app
2. Select "Monetization" → "In-App Purchases"
3. Click the "+" button to create new products

#### Product 1: Monthly Subscription
- **Product ID**: `com.snapchef.premium.monthly`
- **Reference Name**: SnapChef Premium Monthly
- **Product Type**: Auto-Renewable Subscription
- **Price**: $4.99 USD (Tier 5)
- **Duration**: 1 Month
- **Description**: Unlock all premium features with monthly access
- **Features**:
  - Unlimited recipe generations
  - Premium challenges
  - 2x Chef Coins
  - Exclusive badges

#### Product 2: Yearly Subscription
- **Product ID**: `com.snapchef.premium.yearly`
- **Reference Name**: SnapChef Premium Yearly
- **Product Type**: Auto-Renewable Subscription
- **Price**: $39.99 USD (Tier 40)
- **Duration**: 1 Year
- **Description**: Best value! Save 33% with yearly access
- **Features**:
  - Everything in monthly
  - Priority support
  - Early access to features

### 3. Create Subscription Group
1. Go to "Subscription Groups"
2. Create new group: "SnapChef Premium"
3. Add both subscriptions to this group
4. Set upgrade/downgrade rules

### 4. Add Localizations
For each product, add localizations:
- Display Name
- Description
- Promotional image (optional)

### 5. Submit for Review
1. Fill out subscription details
2. Add screenshots
3. Provide review notes
4. Submit products for review

## Testing Setup

### 1. Create Sandbox Tester
1. Go to "Users and Access"
2. Select "Sandbox Testers"
3. Create new tester with test email

### 2. Test in Simulator/Device
1. Sign out of App Store on device
2. Run app in debug mode
3. When prompted, sign in with sandbox account
4. Products should load successfully

## Code Configuration

### StoreKit Configuration File
Create `SnapChef.storekit` in Xcode:
1. File → New → File
2. Choose "StoreKit Configuration File"
3. Add your products with same IDs

### Info.plist Requirements
Already configured:
- `SKAdNetworkItems` (if using ads)
- No additional permissions needed

## Common Issues

### "No active account" Error
- Normal in simulator without sandbox account
- Sign in with sandbox tester to resolve

### Products not loading (0 products)
1. Check product IDs match exactly
2. Ensure products are approved in App Store Connect
3. Wait 24 hours after creating products
4. Check internet connection

### Transaction failures
- Sandbox environment may be slow
- Retry after a few minutes
- Check sandbox server status

## Revenue Cat Alternative (Optional)
Consider using Revenue Cat for easier management:
1. Create Revenue Cat account
2. Add SDK to project
3. Configure products in Revenue Cat dashboard
4. Simplified receipt validation

## Checklist
- [ ] Created App ID in App Store Connect
- [ ] Added both subscription products
- [ ] Created subscription group
- [ ] Added localizations
- [ ] Created sandbox tester
- [ ] Tested purchases in sandbox
- [ ] Submitted for review (when ready)