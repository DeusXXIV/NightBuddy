# AdMob Live Ads Checklist (NightBuddy)

Use this checklist when ads are still showing "Test Ad" with production IDs.

## 1) Link the Play Store listing (required)
- Open AdMob → Apps → NightBuddy.
- Click "Add store" and select Google Play.
- Link the correct package (`com.nightbuddy.app` or your real package).
- This triggers the AdMob review for the app.

## 2) Confirm AdMob review status
- AdMob → Apps → NightBuddy:
  - App status should be "Ready".
  - If "Requires review", wait for review to finish after linking the store.

## 3) Check ad serving limits
- AdMob → Policy center:
  - If "Limited ad serving" is active, live ads may not serve.
  - Resolve any policy issues listed there.

## 4) Verify ad units are ready
- AdMob → Ad units:
  - Each ad unit should be "Ready" (not "Inactive" or "In review").
  - Newly created units can take 24–48 hours to stabilize.

## 5) app-ads.txt (if you have a website)
- Publish `app-ads.txt` to your site root.
- AdMob → App-ads.txt should show "Verified".
- If you do not have a website, skip this step.

## 6) Ensure device isn’t marked as test
- If you used Ad Inspector, remove the device from test devices.
- Clear app data after changing test device settings.

## 7) Confirm Play listing is live
- Play Console → All apps → NightBuddy:
  - Ensure the listing is published (not Draft).
  - Check internal/production track status.

## Notes
- During review or limited serving, AdMob may show "Test Ad" even with production IDs.
- If the app was just linked, wait 1–3 business days for review.
