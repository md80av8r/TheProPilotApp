//  NOC WebView Integration - Quick Start Guide
//  
//  How to access the NOC web portal from anywhere in your app
//

/*

INTEGRATION COMPLETE ✅

The NOC web portal is now fully integrated into your app with support for:
✓ Separate credentials for webcal sync vs. web portal
✓ Automatic authentication handling
✓ Session persistence with cookies
✓ Navigation controls (back, forward, refresh)
✓ Error handling and loading states
✓ Works on iPhone and iPad


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 HOW TO ACCESS THE NOC PORTAL

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Method 1: From Schedule View (RECOMMENDED)
──────────────────────────────────────────
1. Open "Roster Schedule" tab
2. Tap the menu (•••) in top right
3. Select "Open NOC Portal"
4. Portal opens in full-screen sheet


Method 2: From NOC Roster View
──────────────────────────────
1. Open "Roster Schedule" tab  
2. Tap "NOC" toggle in top left
3. Tap "Full Roster" tab
4. Portal loads automatically


Method 3: From Settings
───────────────────────
1. Open Settings
2. Go to "NOC Settings"
3. Scroll to Actions section
4. Tap "Open NOC Web Portal"


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚙️ SETUP (ONE TIME)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Step 1: Configure Calendar Sync
────────────────────────────────
Settings → NOC Settings → Calendar Sync (webcal)

   Username: [your webcal username]
   Password: [your webcal password]  
   Roster URL: webcal://jus.noc.vmc.navblue.cloud/...


Step 2: Test Calendar Sync
───────────────────────────
Tap "Sync Now" to verify your calendar credentials work


Step 3: Configure Web Portal (if different credentials)
────────────────────────────────────────────────────────
Settings → NOC Settings → Web Portal (Optional)

   Web Portal URL: https://jus.noc.vmc.navblue.cloud/Raido/Default.aspx
   Web Username: [leave blank to use calendar username]
   Web Password: [leave blank to use calendar password]

⚠️ Only fill in Web Username/Password if your NOC system uses 
   different credentials for the web portal vs. calendar sync


Step 4: Test Web Portal
───────────────────────
Tap "Open NOC Web Portal" to verify login works


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 TROUBLESHOOTING

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Problem: "Authentication Failed"
─────────────────────────────────
Solution:
  1. Verify web credentials are correct
  2. Try entering SEPARATE web username/password in settings
  3. Some airlines use different auth for web vs. calendar
  4. Test login in Safari first to verify credentials


Problem: Portal Won't Load
───────────────────────────
Solution:
  1. Check internet connection
  2. Verify URL is: https://jus.noc.vmc.navblue.cloud/Raido/Default.aspx
  3. Try tapping the refresh button (↻)
  4. Try Menu → "Clear Cookies" to start fresh
  5. Restart app and try again


Problem: Wrong Page After Login
────────────────────────────────
Solution:
  1. This is normal - NOC may redirect after authentication
  2. Use navigation controls to get to your desired page
  3. Or tap Menu → "Go to Home" to reset


Problem: Credentials Not Saving
────────────────────────────────
Solution:
  1. Re-enter credentials
  2. Tap "Done" to save settings
  3. Restart app
  4. Check Settings again to verify they persisted


Problem: "Configure in Settings" Message
─────────────────────────────────────────
Solution:
  1. You haven't set up the web portal URL yet
  2. Go to Settings → NOC Settings
  3. Fill in at least the Web Portal URL field


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 TIPS & TRICKS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Navigation Gestures
───────────────────
  • Swipe left/right to go back/forward
  • Tap back button (◀) to go back  
  • Tap forward button (▶) to go forward
  • Tap refresh (↻) to reload current page


Menu Options (•••)
──────────────────
  • Reload - Refresh current page
  • Go to Home - Return to portal homepage
  • Clear Cookies - Sign out and clear session


Using Both Calendars
────────────────────
  • "Personal" = Your synced schedule from webcal
  • "NOC" = Airline-wide roster (web portal view)
  • Switch between them with the toggle in top left


Saving Data Usage
─────────────────
  • Portal uses web data - be mindful on cellular
  • Consider using on WiFi only for heavy browsing
  • Calendar sync is minimal data usage


Session Management
──────────────────
  • Portal stays logged in via cookies
  • Survives app restarts
  • To force logout: Menu → "Clear Cookies"


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔒 SECURITY & PRIVACY

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ All connections use HTTPS (encrypted)
✓ Credentials stored securely in app storage
✓ Basic Auth sent only over secure connection
✓ Cookies managed by WebKit secure storage
✓ No credentials logged or exposed
✓ Session isolated to app (not shared with Safari)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 SUPPORTED FEATURES

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Full web navigation
✅ Back/forward gestures  
✅ Page refresh
✅ Loading progress indicator
✅ Error handling
✅ Cookie persistence
✅ Session management
✅ Secure authentication
✅ Responsive to orientation
✅ Works on iPhone & iPad
✅ URL display
✅ Network error recovery


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎨 ADDING TO OTHER VIEWS (FOR DEVELOPERS)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


You can add NOC portal access anywhere in the app using NOCQuickAccessButton:


// Compact Button (Small, Inline)
NOCQuickAccessButton(settings: nocSettings, style: .compact)


// Card Button (Large, Featured)
NOCQuickAccessButton(settings: nocSettings, style: .card)
  .padding()


// Toolbar Button (Icon Only)
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        NOCQuickAccessButton(settings: nocSettings, style: .toolbar)
    }
}


// Direct WebView (No Button)
.sheet(isPresented: $showPortal) {
    NOCWebPortalView(settings: nocSettings)
}


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 FILES ADDED/MODIFIED

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


New Files:
──────────
  ✨ NOCWebPortalView.swift - Full web portal implementation
  ✨ NOCQuickAccessButton.swift - Reusable access button
  ✨ NOC_WEBVIEW_INTEGRATION.md - Technical documentation


Modified Files:
───────────────
  📝 NOCSettingsStore.swift - Added separate web credentials
  📝 NOCSettingsView.swift - Updated UI for new credential fields
  📝 ScheduleCalendarView.swift - Added portal menu option


Unchanged Files:
────────────────
  ✓ NOCRosterGanttView.swift - Already had portal support
  ✓ All other views - No changes needed


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📞 SUPPORT

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

If you experience issues:

1. Check NOC portal works in Safari with your credentials
2. Verify you're using the correct URL
3. Confirm your organization uses Basic HTTP Auth (not SSO)
4. Try clearing cookies and logging in again
5. Check for app updates

For SSO/OAuth organizations: Additional modifications may be needed.


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✈️ HAPPY FLYING! ✈️

*/
