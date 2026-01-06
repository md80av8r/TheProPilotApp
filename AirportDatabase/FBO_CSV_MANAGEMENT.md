# FBO CSV Management Tools

## Quick Reference Commands

### Count FBOs in CSV
```bash
# Total FBOs (excluding header)
tail -n +2 propilot_fbos.csv | wc -l

# FBOs per airport
tail -n +2 propilot_fbos.csv | cut -d',' -f1 | sort | uniq -c | sort -rn
```

### Find Duplicates
```bash
# Find duplicate FBO names at same airport
tail -n +2 propilot_fbos.csv | awk -F',' '{print $1 "," $2}' | sort | uniq -c | sort -rn | grep -v "^ *1 "
```

### Validate CSV Format
```bash
# Check all rows have 20 columns
awk -F',' 'NF != 20 { print NR ": " NF " fields - " $0 }' propilot_fbos.csv
```

### Sort by Airport
```bash
# Sort CSV by airport code (preserving header)
(head -n1 propilot_fbos.csv && tail -n +2 propilot_fbos.csv | sort -t',' -k1,1) > propilot_fbos_sorted.csv
```

---

## CSV Column Reference

| Column # | Field Name        | Type    | Example              | Notes                          |
|----------|-------------------|---------|----------------------|--------------------------------|
| 1        | airport_code      | String  | KSFO                 | ICAO code (uppercase)          |
| 2        | name              | String  | Signature Aviation   | FBO name                       |
| 3        | phone             | String  | 650-877-6800         | Phone with dashes              |
| 4        | unicom            | String  | 130.60               | Frequency (no MHz)             |
| 5        | website           | String  | https://...          | Full URL                       |
| 6        | jet_a_price       | Double  | 6.50                 | Price per gallon               |
| 7        | avgas_price       | Double  | 7.25                 | Price per gallon               |
| 8        | crew_cars         | Boolean | Yes / 1 / true       | Any truthy value               |
| 9        | crew_lounge       | Boolean | Yes / 1 / true       | Any truthy value               |
| 10       | catering          | Boolean | Yes / 1 / true       | Any truthy value               |
| 11       | maintenance       | Boolean | Yes / 1 / true       | Any truthy value               |
| 12       | hangars           | Boolean | Yes / 1 / true       | Any truthy value               |
| 13       | deice             | Boolean | Yes / 1 / true       | Any truthy value               |
| 14       | oxygen            | Boolean | Yes / 1 / true       | Any truthy value               |
| 15       | gpu               | Boolean | Yes / 1 / true       | Any truthy value               |
| 16       | lav               | Boolean | Yes / 1 / true       | Any truthy value               |
| 17       | handling_fee      | Double  | 50.00                | Dollar amount                  |
| 18       | overnight_fee     | Double  | 75.00                | Dollar amount                  |
| 19       | ramp_fee          | Double  | 25.00                | Dollar amount                  |
| 20       | ramp_fee_waived   | Boolean | Yes / 1 / true       | Waived with fuel purchase      |

---

## Adding New FBOs

### Template Row
```csv
KXXX,FBO Name,555-123-4567,123.45,https://example.com,6.50,7.25,Yes,Yes,Yes,Yes,Yes,Yes,Yes,Yes,Yes,50.00,75.00,25.00,Yes
```

### Step-by-Step

1. **Find Airport Code**
   ```bash
   # Search for airport in airports CSV
   grep -i "san francisco" propilot_airports.csv
   # Result: ...KSFO...
   ```

2. **Research FBO**
   - Visit FBO website
   - Call for current prices
   - Verify amenities
   - Check AirNav, ForeFlight, or FltPlan

3. **Add Row to CSV**
   ```csv
   KSFO,New FBO Name,650-555-1234,130.75,https://newfbo.com,6.75,7.50,Yes,Yes,No,Yes,Yes,Yes,Yes,Yes,Yes,,,35.00,Yes
   ```

4. **Validate Entry**
   ```bash
   # Check last row has 20 fields
   tail -n1 propilot_fbos.csv | awk -F',' '{print NF}'
   # Should print: 20
   ```

5. **Increment Version**
   ```swift
   // In AirportDatabaseManager.swift
   private let currentFBOCSVVersion = 3  // ← Increment
   ```

---

## Bulk Update Scripts

### Update Fuel Prices for Airport
```python
#!/usr/bin/env python3
import csv
import sys

airport_code = "KSFO"
new_jet_a = 6.85
new_avgas = 7.40

with open('propilot_fbos.csv', 'r') as f:
    reader = csv.DictReader(f)
    rows = list(reader)

for row in rows:
    if row['airport_code'] == airport_code:
        row['jet_a_price'] = new_jet_a
        row['avgas_price'] = new_avgas
        print(f"Updated {row['name']}")

with open('propilot_fbos.csv', 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=reader.fieldnames)
    writer.writeheader()
    writer.writerows(rows)
```

### Add Missing Airports
```bash
# Find airports with no FBOs
comm -23 <(tail -n +2 propilot_airports.csv | cut -d',' -f13 | sort -u) \
         <(tail -n +2 propilot_fbos.csv | cut -d',' -f1 | sort -u) \
         > airports_without_fbos.txt
```

### Verify Phone Numbers
```bash
# Find invalid phone formats
tail -n +2 propilot_fbos.csv | awk -F',' '$3 !~ /^[0-9-]+$/ && $3 != "" { print NR ": " $1 " - " $2 " - " $3 }'
```

---

## Data Sources for FBO Research

### Official Sources
1. **AirNav.com** - Comprehensive FBO listings
   ```
   https://www.airnav.com/airport/KSFO
   ```

2. **FAA Chart Supplement** - Official FAA data
   ```
   https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/dafd/
   ```

3. **FBO Websites** - Direct from source
   - Signature Aviation: signature.aero
   - Atlantic Aviation: atlanticaviation.com
   - Million Air: millionair.com

### Crowdsourced
1. **ForeFlight** - Pilot community
2. **FltPlan.com** - Flight planning
3. **Pilot Forums** - Reddit r/flying, BeechTalk, etc.

### Price Aggregators
1. **100LL.com** - Fuel price crowdsourcing
2. **AirNav Fuel Prices** - User-reported
3. **FlyQ** - Community fuel prices

---

## Quality Control Checklist

Before releasing CSV update:

- [ ] All rows have exactly 20 fields
- [ ] No duplicate FBO names at same airport
- [ ] Airport codes are valid ICAO (exist in airports CSV)
- [ ] Phone numbers use consistent format (555-123-4567)
- [ ] Frequencies are numeric only (no "MHz")
- [ ] Prices are realistic ($5-$15 per gallon typically)
- [ ] Boolean fields use consistent values ("Yes" or "1")
- [ ] Version number incremented in code
- [ ] Sort by airport code (optional, for readability)
- [ ] Test on device before release

---

## Version History

Keep a changelog:

```markdown
## CSV Version History

### v3 (2026-01-15)
- Added 5 new FBOs at KLAS
- Updated fuel prices for all KSFO FBOs
- Removed Atlantic Aviation at KMIA (closed)
- Fixed phone number format for KDEN Signature

### v2 (2026-01-03)
- Initial release with 164 FBOs
- 82 airports covered
- Focus on major US airports
```

---

## Testing New CSV

### Xcode Testing
1. Add CSV to project (replace old one)
2. Increment version in code
3. Clean build folder (⌘⇧K)
4. Run on simulator
5. Check console for load message:
   ```
   ✅ Loaded X FBOs from CSV v3 for Y airports
   ```
6. View airport with new FBO
7. Verify all fields display correctly

### Test Cases
- [ ] FBO appears in list
- [ ] Contact info displays
- [ ] Fuel prices show
- [ ] Amenities render
- [ ] Fees display correctly
- [ ] "Verified" badge shows
- [ ] "Baseline Data" badge shows
- [ ] Phone link works
- [ ] Fuel update preserves data

---

## Common Issues

### Issue: FBO Not Appearing
**Cause:** Airport code mismatch

**Fix:**
```bash
# Check exact airport code in airports CSV
grep -i "san francisco" propilot_airports.csv | cut -d',' -f13
# Use exact match in FBOs CSV
```

### Issue: Fuel Prices Not Showing
**Cause:** Empty or invalid price field

**Fix:** Use numeric value or leave empty:
```csv
KSFO,Signature,555-1234,130.60,,6.50,,Yes,... # Only Jet A
KSFO,Atlantic,555-5678,130.60,,,7.25,Yes,...  # Only AvGas
```

### Issue: Amenities Not Displaying
**Cause:** Field value not recognized as boolean

**Fix:** Use "Yes", "1", or "true" (case-insensitive):
```csv
# Valid
Yes,Yes,No,1,true,FALSE

# Invalid
X,✓,N,available,unavailable
```

### Issue: Duplicate FBOs After Merge
**Cause:** Name variation (e.g., "Signature" vs "Signature Aviation")

**Fix:** Use consistent names matching CloudKit:
```bash
# Check existing CloudKit names
tail -n +2 propilot_fbos.csv | grep KSFO | cut -d',' -f2
```

---

## Advanced: Automated Updates

### GitHub Actions Workflow
```yaml
name: Validate FBO CSV

on:
  push:
    paths:
      - 'propilot_fbos.csv'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Check CSV format
        run: |
          # All rows have 20 fields
          awk -F',' 'NF != 20 { print "ERROR line " NR; exit 1 }' propilot_fbos.csv
      - name: Check for duplicates
        run: |
          # No duplicate airport+name combinations
          tail -n +2 propilot_fbos.csv | \
            awk -F',' '{print $1 "," $2}' | \
            sort | uniq -d | \
            if [ $(wc -l) -gt 0 ]; then echo "Duplicates found!"; exit 1; fi
```

---

## Future Enhancements

### Potential Tools
1. **CSV Editor UI** - SwiftUI admin panel
2. **Import from AirNav** - Automated scraping
3. **Fuel Price API** - Automated updates
4. **User Contribution Review** - Promote CloudKit → CSV
5. **A/B Testing** - Track which sources users trust

### Data Enrichment
- Hours of operation
- FBO website/photos
- Amenity details (crew car count, lounge hours)
- Historical fuel price trends
- User ratings per amenity

---

**Last Updated:** 2026-01-03  
**Current CSV Version:** 2  
**Maintained By:** Developer
