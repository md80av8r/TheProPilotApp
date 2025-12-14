# ProPilot EAPIS Filing System

## 🎯 What This Does

A complete EAPIS (Electronic Advance Passenger Information System) module for ProPilot that lets you:

- **Manage Passengers** - Store passenger details, passport info, and travel documents
- **Create Manifests** - Build flight manifests linking passengers to your trips
- **Generate Documents** - Automatically generate country-specific customs forms
- **Export & Share** - Email, print, or share manifests with authorities

## 📦 What You're Getting

### 9 Complete Files Ready to Use:

1. **EAPISPassenger.swift** - Passenger data model (220 lines)
2. **EAPISManifest.swift** - Flight manifest model (200 lines)
3. **EAPISCloudKitManager.swift** - CloudKit sync engine (280 lines)
4. **EAPISDocumentGenerator.swift** - Document generation (420 lines)
5. **EAPISView.swift** - Main UI with tabs (320 lines)
6. **AddEditPassengerView.swift** - Passenger forms (380 lines)
7. **AddEditManifestView.swift** - Manifest forms (420 lines)
8. **DocumentExportView.swift** - Export & sharing (280 lines)
9. **EAPIS_INTEGRATION_GUIDE.md** - Complete setup instructions

**Total:** ~2,500 lines of production-ready code

## 🌍 Supported Destinations

### Document Formats Available:

✈️ **GENDEC** (General Declaration)
- Universal format accepted worldwide
- Standard for general aviation

🍁 **Canada eManifest**
- Canada Border Services format
- Required for all arrivals

🌮 **Mexico Declaration**  
- Bilingual format (English/Spanish)
- Mexican customs requirements

🏝️ **Caribbean/Cuba**
- Standard format for island nations
- Bahamas, Cayman Islands, Cuba, etc.

🇪🇺 **Europe/Schengen**
- EU entry declaration
- Detailed passenger manifest

## 🚀 Quick Start

### 1. Add to Your Project
Drag all `.swift` files into Xcode (see integration guide for details)

### 2. Set Up CloudKit
Add two record types: `Passenger` and `EAPISManifest` (schema in guide)

### 3. Add to Your App
```swift
// Add as a new tab in your ContentView
TabView {
    // ... your existing tabs
    
    EAPISView()
        .tabItem {
            Label("EAPIS", systemImage: "doc.text.fill")
        }
}
```

### 4. Start Using
1. Add passengers with passport details
2. Create manifests for your international flights  
3. Generate country-specific documents
4. Share/email/print for customs

## ✨ Key Features

### Passenger Management
- Full passport & travel document tracking
- Expiration date warnings (6-month rule)
- Favorite passengers for quick access
- Address & contact information
- CloudKit sync across devices

### Smart Manifests
- Link to your ProPilot trips (optional)
- Multiple passengers per flight
- Status tracking: Draft → Ready → Filed
- Confirmation number storage
- Customs declarations

### Professional Documents
- Country-specific formatting
- Bilingual where required
- Proper date/time formats (UTC)
- All required fields included
- Ready to submit to authorities

### Easy Export
- iOS native share sheet
- Copy to clipboard (quick paste)
- Save as text file
- Email directly
- Print support

## 🔒 Privacy & Security

- ✅ CloudKit private database (encrypted)
- ✅ No third-party services
- ✅ Offline access via App Group cache
- ✅ User controls all data
- ✅ No tracking or analytics

## 💡 Usage Examples

### Scenario 1: Flying to Mexico
```
1. Add your passengers (one-time setup)
2. Create manifest for MMCU flight
3. Select "Mexico Declaration" format
4. Email to yourself for printing
5. Present at Mexican customs
```

### Scenario 2: Canada Trip
```
1. Create manifest with all PAX
2. Generate "Canada eManifest"  
3. Share with co-pilot
4. File with Canada Border Services
5. Save confirmation number in app
```

### Scenario 3: Caribbean Charter
```
1. Add charter passengers
2. Link to your ProPilot trip
3. Generate Caribbean format
4. Copy to clipboard
5. Paste into customs website
```

## 🎓 For Beginners

### What is EAPIS?
When flying internationally from the US, you need to provide passenger and flight information to the destination country. EAPIS is the system for filing this information electronically.

### Do I Need This?
**Yes**, if you fly internationally to:
- Canada
- Mexico  
- Caribbean islands
- Central/South America
- Europe

**No**, if you only fly domestic US flights.

### What Information Do I Need?
For each passenger:
- Full name (as on passport)
- Date of birth
- Passport number & country
- Nationality
- Address

For the flight:
- Aircraft registration
- Departure/arrival airports
- Date & time (UTC)
- Purpose of flight

## 🔗 Integration with ProPilot

### Optional Enhancements:

**Link to Trips**
The manifest model has a `tripID` field. You can auto-populate manifests from your existing trips.

**Auto-fill Aircraft**
Pull registration from your aircraft profile/settings.

**Pre-fill Pilot Info**
Store your license number in UserDefaults for quick filling.

**Weight & Balance**
Use passenger weights for W&B calculations (weight field included).

## 📚 Documentation

See **EAPIS_INTEGRATION_GUIDE.md** for:
- Complete CloudKit schema
- Step-by-step setup
- Code examples
- Testing checklist
- Troubleshooting tips

## 🎯 Real-World Use

This system is designed for actual flight operations:
- ✈️ Quick passenger entry during trip planning
- ⏱️ Generate docs in under 30 seconds
- 📱 Works offline (cached data)
- 🔄 Syncs across iPhone/iPad
- 💼 Professional formatting for authorities

## 🚧 Future Ideas

Want to enhance this? Consider adding:
- PDF export (vs plain text)
- OCR for passport scanning  
- Trip auto-population
- Historical manifest archive
- Crew rostering integration
- QR codes for mobile check-in

## 📞 Support

Questions? Check:
1. **Integration Guide** - Setup instructions
2. **Code Comments** - Inline documentation
3. **CloudKit Dashboard** - Sync status

## 📝 Notes

- All times in UTC (as required by ICAO)
- Supports iOS 16.0+
- Uses SwiftUI throughout
- CloudKit account required
- ~2,500 lines of code
- Production-ready quality

---

**Ready to fly internationally? Let's get this integrated! 🛫**

See `EAPIS_INTEGRATION_GUIDE.md` for detailed setup instructions.