# NOC WebView Integration Summary

## Overview
This integration adds full webview support for the NOC portal, allowing users to access the full roster system directly within the app. Since NOC uses different authentication for the webcal calendar sync versus the HTTPS web portal, we've separated the credentials.

## What Changed

### 1. **NOCSettingsStore.swift** - Separate Credentials
Added separate credential fields for web portal access:
- `webUsername` - Username for HTTPS portal (optional - falls back to calendar username)
- `webPassword` - Password for HTTPS portal (optional - falls back to calendar password)  
- `webPortalURL` - Defaults to: `https://jus.noc.vmc.navblue.cloud/Raido/Default.aspx`

**Existing calendar sync credentials remain unchanged:**
- `username` - Username for webcal calendar
- `password` - Password for webcal calendar
- `rosterURL` - Your webcal roster URL

### 2. **NOCWebPortalView.swift** - New File
A complete authenticated webview implementation with:
- **Basic HTTP Authentication** - Automatically handles login
- **Cookie Management** - Maintains session across app launches
- **Navigation Controls** - Back, forward, refresh buttons
- **URL Display** - Shows current page location
- **Error Handling** - Graceful error messages
- **Loading States** - Progress indicator during page loads

**Features:**
```swift
- Full web navigation with gestures
- Clear cookies option (sign out)
- Automatic credential injection
- Secure credential storage
- Responsive to orientation changes
```

### 3. **NOCSettingsView.swift** - Updated UI
The settings view now has two separate sections:

**Calendar Sync (webcal) Section:**
- Username
- Password  
- Roster URL

**Web Portal (Optional) Section:**
- Web Portal URL (with reset button)
- Web Username (if different from calendar)
- Web Password (if different from calendar)
- Helper text explaining fallback behavior

### 4. **Integration Points**

#### From ScheduleCalendarView:
The NOC toggle already exists in your schedule view:
```swift
ToolbarItem(placement: .navigationBarLeading) {
    scheduleTypeToggle  // Switches to NOCRosterGanttView
}
```

#### From NOCRosterGanttView:
Click the "Full Roster" tab or use the quick action button:
```swift
.sheet(isPresented: $showingWebPortal) {
    NOCWebPortalView(settings: nocSettings)
}
```

#### From Settings:
Open NOC Web Portal button now available in the Actions section.

## How to Use

### Setup (One Time)

1. **Go to Settings → NOC Settings**

2. **Enter Calendar Credentials:**
   - Username (for webcal)
   - Password (for webcal)
   - Roster URL (your webcal URL)

3. **Test Sync:**
   - Tap "Sync Now" to verify calendar works

4. **Enter Web Credentials (if different):**
   - Leave blank to use same credentials as calendar
   - OR enter separate web username/password if NOC uses different auth

5. **Verify Web Portal URL:**
   - Default: `https://jus.noc.vmc.navblue.cloud/Raido/Default.aspx`
   - Modify if your organization uses a different URL

### Daily Use

**Access the Web Portal:**
1. From Schedule → Tap "NOC" toggle → Tap "Full Roster" tab
2. OR Settings → NOC Settings → "Open NOC Web Portal"

**Navigation:**
- Swipe left/right for back/forward
- Tap back/forward buttons
- Tap refresh to reload
- Menu (•••) for additional options

**Sign Out:**
- Menu → "Clear Cookies" (forces re-authentication)

## Technical Details

### Authentication Flow
1. App checks for `webUsername` and `webPassword`
2. If empty, falls back to `username` and `password`
3. Creates Basic Auth header: `Authorization: Basic [base64credentials]`
4. WebKit automatically handles subsequent auth challenges
5. Cookies maintained for session persistence

### Security
- All credentials stored in `UserDefaults` (app-group suite)
- Basic Auth sent over HTTPS only
- WebKit secure data store for cookies
- Credentials never logged or exposed

### Error Handling
- Invalid credentials → Shows auth challenge dialog
- Network errors → Displays error message with retry
- SSL errors → Uses default handling (won't bypass security)
- Timeout → 30 second timeout with error message

## Troubleshooting

### "Authentication Failed"
- Verify web credentials are correct
- Try entering separate web username/password
- Check if NOC portal uses different auth than calendar

### "Page Won't Load"
- Check internet connection
- Verify web portal URL is correct
- Try "Reload" button
- Try "Clear Cookies" to start fresh

### "Wrong Page Showing"
- The portal may redirect after login
- This is normal - navigate to your desired page
- Use "Go to Home" to reset to portal homepage

### "Credentials Not Saving"
- Check that UserDefaults isn't restricted
- Try re-entering credentials
- Restart app and check if they persist

## Testing Checklist

- [ ] Calendar sync works with existing credentials
- [ ] Web portal loads with same credentials
- [ ] Web portal loads with different credentials
- [ ] Back/forward navigation works
- [ ] Refresh button works
- [ ] Clear cookies signs out properly
- [ ] Authentication persists across app launches
- [ ] Error messages display for invalid credentials
- [ ] Loading indicator shows during page loads
- [ ] Orientation changes don't break layout

## Future Enhancements

Potential improvements:
- [ ] JavaScript injection for enhanced functionality
- [ ] Download handler for files
- [ ] Custom user agent string
- [ ] Remember last visited page
- [ ] Add bookmark functionality
- [ ] Share current page URL
- [ ] Print support
- [ ] Split view (iPad)

## Support

If users have issues:
1. Verify they have valid NOC portal access
2. Test credentials in Safari first
3. Check if organization uses custom SSO
4. Confirm portal URL matches organization's system

---

**Note:** This integration assumes NOC uses Basic HTTP Authentication. If your organization uses OAuth, SAML, or other SSO methods, additional modifications may be needed.
