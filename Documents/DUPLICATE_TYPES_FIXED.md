# Duplicate Type Declarations Fixed

## Problem
`WeatherView.swift` contained duplicate declarations of weather models that were already properly defined in `WeatherModels.swift`, causing "ambiguous type" compiler errors throughout the project.

## Root Cause
The comment at the top of `WeatherView.swift` mentioned:
```swift
// NOTE: Weather models are now in WeatherModels.swift for shared use
// These legacy models below are kept temporarily for backwards compatibility
// TODO: Migrate WeatherView to use WeatherModels.swift definitions
```

However, the "temporary" legacy models were never removed, causing conflicts.

## Solution
**Removed** all duplicate type declarations from `WeatherView.swift` (approximately 247 lines):
- ❌ `struct AirportWeather: Identifiable, Codable`
- ❌ `struct METARData: Codable`
- ❌ `struct TAFData: Codable`
- ❌ `struct RawMETAR: Codable`
- ❌ `struct RawTAF: Codable`
- ❌ `enum WindDirection: Codable`
- ❌ `enum VisibilityValue: Codable` (nested in RawMETAR)

**Kept** the canonical definitions in `WeatherModels.swift`:
- ✅ `RawMETAR` (lines 14-142) - Primary API model with full functionality
- ✅ `RawTAF` (lines 145-158) - TAF data model
- ✅ `WindDirection` (lines 161-191) - Enum handling both Int and String
- ✅ `VisibilityValue` (lines 194-224) - Enum handling both Double and String
- ✅ `AirportWeather` (lines 257-265) - **Non-Codable** display model
- ✅ `METARData` (lines 268-293) - **Non-Codable** legacy model
- ✅ `TAFData` (lines 296-301) - **Non-Codable** legacy model

## Key Differences Between Files

### WeatherModels.swift (Canonical - KEEP)
- **`RawMETAR`**: Full-featured API model with computed properties:
  - `windDirection`, `visibility`, `observationTime`, `timeAgo`
  - `tempDewpointSpread`, `isIcingRisk`, `relativeHumidity`
  - Helper extensions for formatting
- **`AirportWeather`**: NOT Codable (by design, contains UUID)
- **`METARData`**: NOT Codable (legacy compatibility model)
- **`TAFData`**: NOT Codable (legacy compatibility model)

### WeatherView.swift (Duplicates - REMOVED)
- Had Codable conformance on `AirportWeather`, `METARData`, `TAFData`
- Had nested `VisibilityValue` enum inside `RawMETAR`
- Less complete implementations
- Were marked as "temporary for backwards compatibility"

## Files Changed
1. **WeatherView.swift** - Removed ~247 lines of duplicate model definitions
2. **DUPLICATE_TYPES_FIXED.md** (this file) - Documentation

## Verification
After this fix, all weather-related types should resolve to `WeatherModels.swift`:
- No more "ambiguous type lookup" errors
- No more "invalid redeclaration" errors
- No more Codable conformance errors
- All files can use unified models

## Related Files
- `WeatherModels.swift` - Canonical weather model definitions
- `WeatherView.swift` - Weather tab UI
- `WeatherService.swift` - Weather data fetching service
- `AirportDetailView.swift` - Airport detail display
- `WEATHER_SERVICES_ARCHITECTURE.md` - Architecture documentation
