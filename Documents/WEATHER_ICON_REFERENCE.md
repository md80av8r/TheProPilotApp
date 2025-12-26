# Weather Icon Visual Reference

## All SF Symbols Used (Filled Variants)

### Precipitation

| Condition | Icon | Symbol Name | Color |
|-----------|------|-------------|-------|
| Thunderstorms | ⛈️ | `cloud.bolt.rain.fill` | Purple |
| Heavy Rain | 🌧️ | `cloud.heavyrain.fill` | Dark Blue |
| Rain | 🌧️ | `cloud.rain.fill` | Blue |
| Drizzle | 🌦️ | `cloud.drizzle.fill` | Blue |
| Snow | 🌨️ | `cloud.snow.fill` | Blue |
| Heavy Snow | 🌨️ | `cloud.snow.fill` | Blue |
| Freezing Rain | 🌨️ | `cloud.sleet.fill` | Cyan |
| Ice Pellets | 🌨️ | `cloud.sleet.fill` | Cyan |
| Hail | 🌨️ | `cloud.hail.fill` | Blue |

### Visibility

| Condition | Icon | Symbol Name | Color |
|-----------|------|-------------|-------|
| Fog | 🌫️ | `cloud.fog.fill` | Gray |
| Mist | 🌫️ | `cloud.fog.fill` | Gray |
| Haze | 🌫️ | `cloud.fog.fill` | Gray |

### Cloud Coverage (Day)

| Condition | Icon | Symbol Name | Color (Flight Category) |
|-----------|------|-------------|------------------------|
| Overcast | ☁️ | `cloud.fill` | Based on category |
| Broken | ☁️ | `cloud.fill` | Based on category |
| Scattered | ⛅ | `cloud.sun.fill` | Based on category |
| Few | 🌤️ | `cloud.sun.fill` | Based on category |
| Clear | ☀️ | `sun.max.fill` | Green (VFR) |

### Cloud Coverage (Night)

| Condition | Icon | Symbol Name | Color (Flight Category) |
|-----------|------|-------------|------------------------|
| Overcast | ☁️ | `cloud.fill` | Based on category |
| Broken | ☁️ | `cloud.fill` | Based on category |
| Scattered | 🌙 | `cloud.moon.fill` | Based on category |
| Few | 🌙 | `cloud.moon.fill` | Based on category |
| Clear | 🌙✨ | `moon.stars.fill` | Green (VFR) |

## Flight Category Colors

| Category | Color | Meaning |
|----------|-------|---------|
| VFR | 🟢 Green | Visual Flight Rules - Good conditions |
| MVFR | 🔵 Blue | Marginal VFR - Marginal conditions |
| IFR | 🟠 Orange | Instrument Flight Rules - Poor conditions |
| LIFR | 🔴 Red | Low IFR - Very poor conditions |

## METAR Weather Codes

### Precipitation Intensifiers
- `-` Light intensity (e.g., `-RA` = light rain)
- ` ` Moderate intensity (e.g., `RA` = rain)
- `+` Heavy intensity (e.g., `+RA` = heavy rain)

### Precipitation Types
- `RA` - Rain
- `DZ` - Drizzle
- `SN` - Snow
- `FZRA` - Freezing Rain
- `PL` - Ice Pellets
- `GR` - Hail (large)
- `GS` - Small hail/snow pellets

### Obscuration
- `FG` - Fog
- `BR` - Mist
- `HZ` - Haze
- `FU` - Smoke
- `VA` - Volcanic Ash
- `DU` - Dust
- `SA` - Sand

### Thunderstorms
- `TS` - Thunderstorm
- `TSRA` - Thunderstorm with rain
- `TSGR` - Thunderstorm with hail

### Cloud Coverage
- `CLR` / `SKC` - Clear (0 oktas)
- `FEW` - Few clouds (1-2 oktas)
- `SCT` - Scattered (3-4 oktas)
- `BKN` - Broken (5-7 oktas)
- `OVC` - Overcast (8 oktas)

## Day/Night Detection

**Current Logic**: Simple time-based check
- Night: 18:00 (6 PM) to 06:00 (6 AM) local time
- Day: 06:00 (6 AM) to 18:00 (6 PM) local time

**Icons Affected**:
- Day: `cloud.sun.fill`, `sun.max.fill`
- Night: `cloud.moon.fill`, `moon.stars.fill`

**Future Enhancement**: Use actual sunset/sunrise times based on location coordinates for more accuracy.

## Icon Selection Examples

### Example 1: Thunderstorm with Rain
```
METAR: KORD 121856Z 27015G25KT 10SM TSRA BKN020 OVC040 20/18 A2990
Icon: ⛈️ cloud.bolt.rain.fill
Color: Purple
Reason: TS (thunderstorm) detected in weather string
```

### Example 2: Light Rain
```
METAR: KJFK 121851Z 09012KT 5SM -RA BR BKN008 OVC015 12/11 A2985
Icon: 🌧️ cloud.rain.fill
Color: Blue
Reason: -RA (light rain) detected
```

### Example 3: Fog
```
METAR: KSFO 121856Z 00000KT 1/4SM FG VV001 15/15 A2995
Icon: 🌫️ cloud.fog.fill
Color: Gray
Reason: FG (fog) with low visibility
```

### Example 4: Clear Day
```
METAR: KPHX 121856Z 05008KT 10SM CLR 28/05 A3012
Icon: ☀️ sun.max.fill
Color: Green (VFR)
Reason: CLR (clear) with VFR conditions, daytime
```

### Example 5: Scattered Clouds at Night
```
METAR: KLAS 120356Z 22012KT 10SM SCT250 18/03 A3005
Icon: 🌙 cloud.moon.fill
Color: Green (VFR)
Reason: SCT (scattered) at night with VFR conditions
```

## Color Priority

When multiple conditions exist, color is determined by severity:

1. 🟣 **Purple** - Thunderstorms (highest priority - most dangerous)
2. 🔵 **Dark Blue** - Heavy precipitation
3. 🔵 **Blue** - Moderate precipitation
4. 🔵 **Cyan** - Icing conditions
5. ⚫ **Gray** - Reduced visibility
6. 🟠 **Orange/Red** - Flight category (IFR/LIFR)
7. 🔵 **Blue** - MVFR
8. 🟢 **Green** - VFR

## Testing Checklist

To verify icon system works correctly, test with these METAR examples:

- [ ] Thunderstorm: `TSRA`
- [ ] Heavy rain: `+RA`
- [ ] Light rain: `-RA`
- [ ] Drizzle: `DZ`
- [ ] Snow: `SN`
- [ ] Freezing rain: `FZRA`
- [ ] Hail: `GR`
- [ ] Fog: `FG`
- [ ] Overcast: `OVC`
- [ ] Broken: `BKN`
- [ ] Scattered: `SCT`
- [ ] Few: `FEW`
- [ ] Clear: `CLR` or `SKC`
- [ ] Day vs Night icons
- [ ] VFR/MVFR/IFR/LIFR colors

---

**Quick Reference**: When in doubt, check the actual METAR string. Icons follow standard aviation weather reporting conventions! 🛫
