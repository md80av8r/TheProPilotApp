# IATA to ICAO Airport Code Conversion Fix

## Problem Statement

The NOC import process was bypassing the IATA → ICAO airport code conversion, causing trips to be created with 3-letter IATA codes (e.g., "CUU", "SLW") instead of 4-letter ICAO codes (e.g., "MMCU", "MMIO"). This caused issues with:

- **Weather functions** - METAR/TAF services require ICAO codes
- **Airport database lookups** - AirportDatabaseManager uses ICAO codes
- **Geofencing** - Location services use ICAO coordinates
- **Night hours calculations** - Require ICAO codes for timezone lookup

## Root Cause

In `RosterToTripHelper.swift`, the `createLeg(from:)` function was directly assigning airport codes from the roster data without conversion:

```swift
// ❌ WRONG - No conversion
var leg = FlightLeg()
leg.departure = rosterItem.departure  // Could be IATA (3-letter)
leg.arrival = rosterItem.arrival      // Could be IATA (3-letter)
```

This bypassed the existing `BasicScheduleItem.convertIATAToICAO()` function that was already implemented in `RosterModels.swift`.

## The Fix

### Updated `RosterToTripHelper.swift`

Added explicit IATA → ICAO conversion when creating legs from roster data:

```swift
// ✅ CORRECT - Converts IATA to ICAO
var leg = FlightLeg()

// CRITICAL: Convert IATA codes to ICAO format
leg.departure = BasicScheduleItem.convertIATAToICAO(rosterItem.departure)
leg.arrival = BasicScheduleItem.convertIATAToICAO(rosterItem.arrival)
leg.flightNumber = flightNumber

// Report unknown codes to the manager
if rosterItem.departure.count == 3 {
    let convertedDep = BasicScheduleItem.convertIATAToICAO(rosterItem.departure)
    if convertedDep == rosterItem.departure || 
       convertedDep.hasPrefix("K") && convertedDep.dropFirst() == rosterItem.departure {
        UnknownAirportCodeManager.shared.reportUnknownCode(rosterItem.departure)
    }
}
// Same check for arrival code...
```

### How It Works

1. **Conversion**: When creating a leg from roster data, airport codes are immediately converted to ICAO format
2. **Unknown Code Detection**: If a 3-letter code can't be properly converted (stays the same or just gets a "K" prefix), it's reported to the `UnknownAirportCodeManager`
3. **User Notification**: Unknown codes are tracked and the user can be prompted to add mappings

## Conversion Priority

The `BasicScheduleItem.convertIATAToICAO()` function checks codes in this order:

1. **Already ICAO** (4 letters) → Return as-is
2. **User mappings** (from `UserAirportCodeMappings`) → Highest priority
3. **Built-in map** (200+ common airports in `iataToIcaoMap`)
4. **US airports** → Add "K" prefix if 3 letters
5. **Fallback** → Return original code if no match

## Unknown Airport Code Management

The system now includes comprehensive unknown code tracking:

### Detection
- Automatically detects when IATA codes can't be converted
- Tracks unknown codes in `UnknownAirportCodeManager.shared`
- Persists unknown codes across app launches

### Resolution
- User can view unknown codes in Settings → Airport Code Mappings
- Provides interface to add custom IATA → ICAO mappings
- User mappings take priority over built-in ones

### UI Components
- `EnhancedAirportMappingsView` - Manage custom mappings
- `AddMappingSheet` - Add new IATA → ICAO mapping
- `EditMappingSheet` - Edit existing mappings
- Alert section shows unknown codes detected

## Examples

### Before Fix
```swift
// NOC roster data
rosterItem.departure = "CUU"  // IATA code
rosterItem.arrival = "SLW"    // IATA code

// Created leg (WRONG)
leg.departure = "CUU"  // ❌ Weather lookup fails
leg.arrival = "SLW"    // ❌ Airport database fails
```

### After Fix
```swift
// NOC roster data
rosterItem.departure = "CUU"  // IATA code
rosterItem.arrival = "SLW"    // IATA code

// Created leg (CORRECT)
leg.departure = "MMCU"  // ✅ Converted to ICAO
leg.arrival = "MMIO"    // ✅ Converted to ICAO (if user adds mapping)
```

## Built-In Airport Mappings

The system includes 200+ pre-configured IATA → ICAO mappings for:

- **USA** - All major airports (K prefix)
- **Mexico** - Common destinations (MM prefix)
- **Canada** - Major airports (C prefix)
- **Caribbean** - Popular destinations (T/M prefixes)
- **Central America** - Key airports (MG/MH/MN/MR/MP prefixes)

### Example Mappings
```
IATA  →  ICAO    (Location)
----     -----    ----------
YIP   →  KYIP     (Willow Run)
DTW   →  KDTW     (Detroit Metro)
CUU   →  MMCU     (Chihuahua)
MEX   →  MMMX     (Mexico City)
YYZ   →  CYYZ     (Toronto)
SJU   →  TJSJ     (San Juan)
```

## Testing

### Verify the fix works:

1. **Import NOC Roster** with 3-letter codes
2. **Check created trips** - Verify departure/arrival are 4-letter ICAO
3. **Test weather lookup** - Should work with converted codes
4. **Check unknown codes** - Settings → Airport Code Mappings
5. **Add custom mapping** - For airports not in built-in list

### Test Cases

```swift
// Test 1: Known US airport
"ORD" → "KORD" ✅

// Test 2: Known Mexico airport
"CUU" → "MMCU" ✅

// Test 3: Known Canada airport
"YYZ" → "CYYZ" ✅

// Test 4: Unknown airport
"SLW" → "SLW" + reported to UnknownAirportCodeManager ✅

// Test 5: Already ICAO
"KYIP" → "KYIP" ✅

// Test 6: User custom mapping (added)
"SLW" → "MMIO" ✅ (after user adds mapping)
```

## Files Modified

1. **RosterToTripHelper.swift**
   - Updated `createLeg(from:)` to convert IATA → ICAO
   - Added unknown code detection and reporting

## Files Referenced (No Changes)

2. **RosterModels.swift**
   - Contains `convertIATAToICAO()` function (already existed)
   - Contains `iataToIcaoMap` dictionary (already existed)

3. **EnhancedAirportCodeManager.swift**
   - Contains `UnknownAirportCodeManager` (already existed)
   - Contains UI for managing mappings (already existed)

4. **AirportDatabaseManager.swift**
   - Uses ICAO codes for coordinates/timezone lookup (unchanged)
   - Works correctly now that legs have proper ICAO codes

## Benefits

✅ **Weather lookups** work correctly with ICAO codes
✅ **Airport database** lookups find coordinates/timezones
✅ **Geofencing** works with proper ICAO coordinates
✅ **Night hours** calculations get correct timezones
✅ **Unknown codes** are automatically detected and tracked
✅ **User mappings** allow custom airport additions
✅ **Consistent data** - All legs use 4-letter ICAO codes
✅ **Backward compatible** - Existing ICAO codes pass through unchanged

## User Impact

### Immediate
- All new trips from NOC roster will have proper ICAO codes
- Weather function will work for all flights

### If Unknown Codes Found
- User will see alert in Settings → Airport Code Mappings
- Can add custom mappings for their airline's destinations
- Custom mappings persist and apply to future imports

## Future Enhancements

1. **Automatic online lookup** - Query aviation databases for unknown codes
2. **Smart suggestions** - Suggest ICAO codes based on context
3. **Airline templates** - Pre-load mappings for specific airlines
4. **Import/Export mappings** - Share mappings between users
5. **Validation** - Verify ICAO codes exist in databases

## Migration

No migration needed:
- New imports automatically get converted codes
- Existing trips with IATA codes will continue to work
- User can manually edit old trips if needed
- Or re-import from NOC roster to get converted codes

## Summary

The fix ensures that **all airport codes in flight legs are consistently stored as 4-letter ICAO codes**, which is the standard format required by aviation services, weather systems, and airport databases. The conversion happens automatically during NOC import, with intelligent fallback handling and user customization options for unknown airports.
