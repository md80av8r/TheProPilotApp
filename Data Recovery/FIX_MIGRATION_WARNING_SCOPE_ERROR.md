# Fix: "Cannot find 'MigrationWarningSettingsRow' in scope" Error

## Problem
The file `DataBackupSettingsView.swift` references two SwiftUI components that are defined in separate files:
1. `MigrationWarningSettingsRow` (from `ContainerMigrationWarning.swift`)
2. `CloudKitStatusBanner` (from `CloudKitErrorHandler.swift`)

## Root Cause
These files might not be included in the same target as `DataBackupSettingsView.swift`, or there's a build order issue.

## Solution

### Option 1: Verify Target Membership (Recommended)
1. In Xcode, select `ContainerMigrationWarning.swift`
2. Open the **File Inspector** (right sidebar, first tab)
3. Under **Target Membership**, ensure your app target is checked ✅
4. Repeat for `CloudKitErrorHandler.swift`
5. Clean build folder: **Product → Clean Build Folder** (Cmd+Shift+K)
6. Rebuild: **Product → Build** (Cmd+B)

### Option 2: Move Components to Same File (Quick Fix)
If Option 1 doesn't work, you can move the component definitions to the same file.

Add these to the bottom of `DataBackupSettingsView.swift`:

```swift
// MARK: - Migration Warning Row (from ContainerMigrationWarning.swift)
struct MigrationWarningSettingsRow: View {
    @ObservedObject var manager = MigrationWarningManager.shared
    @State private var showingWarning = false
    
    var body: some View {
        Button(action: {
            showingWarning = true
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Container Migration Info")
                        .foregroundColor(.primary)
                    Text("Important backup instructions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .sheet(isPresented: $showingWarning) {
            ContainerMigrationWarningView()
        }
    }
}

// MARK: - CloudKit Status Banner (from CloudKitErrorHandler.swift)
struct CloudKitStatusBanner: View {
    @ObservedObject var errorHandler = CloudKitErrorHandler.shared
    @State private var isExpanded = false
    
    var body: some View {
        if errorHandler.shouldShowWarning {
            VStack(spacing: 8) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        
                        Text(errorHandler.syncStatus.displayMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                
                if isExpanded, let advice = errorHandler.userAdvice {
                    Text(advice)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .background(statusBackgroundColor)
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }
    
    private var statusIcon: String {
        switch errorHandler.syncStatus {
        case .failed:
            return "exclamationmark.icloud.fill"
        case .partialFailure:
            return "icloud.slash.fill"
        default:
            return "icloud.fill"
        }
    }
    
    private var statusColor: Color {
        switch errorHandler.syncStatus {
        case .failed:
            return .red
        case .partialFailure:
            return .orange
        default:
            return .green
        }
    }
    
    private var statusBackgroundColor: Color {
        switch errorHandler.syncStatus {
        case .failed:
            return Color.red.opacity(0.1)
        case .partialFailure:
            return Color.orange.opacity(0.1)
        default:
            return Color.green.opacity(0.1)
        }
    }
}
```

### Option 3: Remove Temporarily (If Not Needed)
If you don't need these warnings right now, you can comment them out:

```swift
VStack(spacing: 20) {
    // 🚨 Container Migration Warning (temporarily disabled)
    // if MigrationWarningManager.shared.shouldShowWarning {
    //     MigrationWarningSettingsRow()
    // }
    
    // CloudKit Status Banner (temporarily disabled)
    // CloudKitStatusBanner()

    // iCloud Sync Section
    iCloudSyncSection
    // ...
}
```

## Verification
After applying the fix:
1. Build the project: **Product → Build** (Cmd+B)
2. Check for errors in the **Issue Navigator** (left sidebar, triangle icon)
3. If successful, run on simulator or device

## Why This Happens
In Swift, all types in the same module (app target) are automatically visible to each other. However:
- Files must be included in the target
- Build order might cause temporary issues
- Clean builds resolve most compilation caching issues

## Recommended Actions
1. ✅ Use **Option 1** (verify targets) - most correct approach
2. ✅ Clean build folder after changes
3. ✅ Restart Xcode if issues persist (rare but effective)
4. ❌ Don't use Option 2 unless necessary (duplicates code)

## Additional Notes

### If You See Other "Cannot find in scope" Errors
The same solution applies to:
- `MigrationWarningManager` → defined in `ContainerMigrationWarning.swift`
- `CloudKitErrorHandler` → defined in `CloudKitErrorHandler.swift`
- `ContainerMigrationWarningView` → defined in `ContainerMigrationWarning.swift`

### Project Structure
Your project should have:
```
TheProPilotApp/
├── Data Recovery/
│   └── DataBackupSettingsView.swift ✅
├── CloudKit/
│   ├── CloudKitErrorHandler.swift ✅
│   └── ContainerMigrationWarning.swift ✅
└── ... other files
```

All three files must be in the **same app target** (usually "TheProPilotApp").

## Testing After Fix
Once the error is resolved, test these features:
1. **Migration Warning**: Should show if user has old data
2. **CloudKit Banner**: Should show if sync errors occur
3. **Backup Export**: Should work normally
4. **Backup Import**: Should work in both merge and replace modes

---

**Most likely solution**: Option 1 + Clean Build  
**Fastest solution**: Option 3 (comment out temporarily)  
**Permanent solution if Option 1 fails**: Option 2 (copy components)
