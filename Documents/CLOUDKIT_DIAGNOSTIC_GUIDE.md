# CloudKit Diagnostic Tool - User Guide

## Overview

I've added a comprehensive CloudKit diagnostic tool to ProPilot App to help you test and debug CloudKit connectivity, iCloud sync, and database access.

## What Was Added

### 1. **CloudKitDiagnosticView.swift** (New File)
A complete diagnostic interface that tests:
- ✅ iCloud account status
- ✅ CloudKit container access
- ✅ Private database connectivity (Trip records)
- ✅ Public database connectivity (Airport records)

### 2. **Updated DataBackupSettingsView.swift**
Added a "CloudKit Test" button in the Data Management section that navigates to the diagnostic view.

### 3. **Enhanced CloudKitManager.swift**
Added a `testCloudKitAirportDatabase()` function for console-based testing.

## How to Use

### Option 1: Visual Diagnostic (Recommended)

1. **Launch ProPilot App**
2. **Navigate to**: Settings → Data & Backup
3. **Tap**: "CloudKit Test" (purple button in Data Management section)
4. **View Results**: The diagnostic will automatically run all tests

**What You'll See:**
```
✅ iCloud Account: Available
✅ Container Access: Accessible
✅ Private Database: 5 Trip records found
✅ Found KYIP in CloudKit!
   - Name: Willow Run Airport
   - Runway: 7521 ft
   - Frequencies: TWR:119.300|...
```

**Or if there's an issue:**
```
❌ No records found for KYIP
   → Check: Development vs Production environment
```

### Option 2: Console Testing (For Advanced Debugging)

Add this code to any view or button:

```swift
Button("Test CloudKit") {
    Task {
        await CloudKitManager.shared.testCloudKitAirportDatabase()
    }
}
```

Then check Xcode console for detailed output:
```
🧪 Testing CloudKit Airport Database...
✅ FOUND DATA - CloudKit working!
   Name: Willow Run Airport
   Runway: 7521 ft
   Frequencies: TWR:119.300|...
```

## Features

### Automated Tests
1. **iCloud Account Status**
   - Checks if user is signed in
   - Verifies iCloud is not restricted
   - Suggests fixes if issues found

2. **Container Access**
   - Verifies container ID
   - Tests user record access
   - Confirms CloudKit permissions

3. **Private Database**
   - Queries Trip records
   - Reports sync status
   - Shows number of synced trips

4. **Public Airport Database**
   - Tests KYIP lookup (Willow Run Airport)
   - Validates airport data structure
   - Detects Dev vs Production mismatches

### Manual Airport Lookup
Tap "Test Airport Lookup (KYIP)" to run a focused test on the airport database without running all other tests.

## Test Results Explained

### ✅ Green Checkmark
- Test passed successfully
- No action needed
- System is working correctly

### ❌ Red X
- Test failed
- Review details for specific error
- Follow suggested remediation steps

### Example Issues & Solutions

#### Issue: "No iCloud account"
**Fix**: 
1. Open Settings on iOS device
2. Tap your name at top
3. Sign in with Apple ID
4. Enable iCloud Drive

#### Issue: "No records found for KYIP"
**Fix**:
1. Check CloudKit Dashboard
2. Verify environment (Development vs Production)
3. Confirm airports are uploaded to correct database
4. Ensure `iCloud.com.jkadans.ProPilotApp` container is correct

#### Issue: "Network Unavailable"
**Fix**:
1. Check internet connection
2. Try again in a few moments
3. Verify iCloud services are online (apple.com/support/systemstatus)

## Integration Points

The diagnostic tool integrates with:
- **DataBackupSettingsView**: Navigation link added
- **CloudKitManager**: Extended with test functions
- **LogBookStore**: Uses same CloudKit configuration
- **Airport Database**: Tests public database access

## Developer Notes

### CloudKit Container
```swift
private let container = CKContainer(identifier: "iCloud.com.jkadans.ProPilotApp")
```

### Test Airport
Uses **KYIP (Willow Run Airport)** as the test record because:
- Well-known airport
- Should exist in production database
- Has complete data (name, runway, frequencies)

### Error Handling
The diagnostic gracefully handles:
- Network errors
- Authentication failures
- Missing records
- Permission issues
- Unknown CloudKit errors

## Best Practices

1. **Run diagnostics before reporting sync issues**
2. **Screenshot test results for support tickets**
3. **Test on different devices to isolate device-specific issues**
4. **Re-run tests after making iCloud/CloudKit changes**
5. **Check both Development and Production environments**

## Quick Reference

| Test | What It Checks | Common Issues |
|------|----------------|---------------|
| iCloud Account | Sign-in status | Not signed in, restricted |
| Container Access | App permissions | Wrong container ID |
| Private Database | Trip sync | Network, authentication |
| Airport Database | Public data access | Dev vs Prod mismatch |

## Troubleshooting Commands

### Check Current Environment
```swift
print(CKContainer.default().containerIdentifier)
```

### Manual iCloud Status Check
```swift
Task {
    let status = try await CKContainer.default().accountStatus()
    print("Status: \(status)")
}
```

### List All Trip Records
```swift
await CloudKitManager.shared.debugCloudKitContents()
```

## Next Steps

If all tests pass ✅:
- CloudKit is configured correctly
- Sync should work properly
- No action needed

If tests fail ❌:
1. Review specific error messages
2. Follow suggested remediation
3. Re-run tests after fixes
4. Contact support if issues persist

## Support

For additional help:
1. Export diagnostic results (screenshot)
2. Check Xcode console for detailed logs
3. Verify CloudKit Dashboard configuration
4. Review iCloud sync documentation
