# Schedule View Reordering - UI Flow

## 1. Main Schedule Tab Header (Before Customization)
```
┌────────────────────────────────────────┐
│  [🔵 List ▼]              ● Synced 2h  │
│  Original list view                     │
└────────────────────────────────────────┘
```

## 2. Dropdown Menu (New Option Added)
```
┌────────────────────────────────┐
│ 📋 List              ✓         │
│ 📝 Agenda                      │
│ 📅 Week                        │
│ 📅 Month                       │
│ 📊 3-Day                       │
│ 📅 Work Week                   │
│ ⏱️ Timeline                     │
│ 📅 Year                        │
│ 📊 Gantt                       │
│ ⫘ Split                       │
│ 🔍 Data Analyzer               │
│ ────────────────────────       │
│ ≡ Customize Order...           │ ← NEW!
└────────────────────────────────┘
```

## 3. View Order Editor Sheet
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Cancel  Customize View Order  Save ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                    ┃
┃  ℹ️ Drag to Reorder Views         ┃
┃  Your favorite view will appear    ┃
┃  first when you open the Schedule  ┃
┃                                    ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                    ┃
┃  ≡  📋 List                  #1   ┃ ← Green highlight
┃      Original list view           ┃
┃                                    ┃
┃  ≡  📝 Agenda                #2   ┃
┃      Compact agenda style         ┃
┃                                    ┃
┃  ≡  📅 Week                  #3   ┃
┃      7-day week grid              ┃
┃                                    ┃
┃  ≡  📅 Month                 #4   ┃
┃      Traditional month calendar   ┃
┃                                    ┃
┃  ≡  📊 3-Day                 #5   ┃
┃      3-day detailed view          ┃
┃                                    ┃
┃  ... (more views) ...             ┃
┃                                    ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃     🔄 Reset to Default           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## 4. After Dragging Month to #1
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Cancel  Customize View Order  Save ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                    ┃
┃  ℹ️ Drag to Reorder Views         ┃
┃  Your favorite view will appear    ┃
┃  first when you open the Schedule  ┃
┃                                    ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                                    ┃
┃  ≡  📅 Month                 #1   ┃ ← Green (new favorite!)
┃      Traditional month calendar   ┃
┃                                    ┃
┃  ≡  📋 List                  #2   ┃ ← Was #1
┃      Original list view           ┃
┃                                    ┃
┃  ≡  📝 Agenda                #3   ┃
┃      Compact agenda style         ┃
┃                                    ┃
┃  ... (more views) ...             ┃
┃                                    ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃     🔄 Reset to Default           ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## 5. After Saving - Dropdown Now Shows New Order
```
┌────────────────────────────────┐
│ 📅 Month             ✓         │ ← Now at top!
│ 📋 List                        │
│ 📝 Agenda                      │
│ 📅 Week                        │
│ 📊 3-Day                       │
│ ... (more views) ...           │
│ ────────────────────────       │
│ ≡ Customize Order...           │
└────────────────────────────────┘
```

## 6. Main Schedule Tab Header (After Customization)
```
┌────────────────────────────────────────┐
│  [🔵 Month ▼]             ● Synced 2h  │ ← Changed from "List"
│  Traditional month calendar            │
└────────────────────────────────────────┘
```

## 7. Next Time User Opens Schedule Tab
```
Opens Schedule Tab
      ↓
Automatically loads "Month" view
      ↓
No need to switch views every time!
```

---

## Visual Elements Explained

### Drag Handle (≡)
- Three horizontal lines on the left
- Visual affordance for dragging
- iOS standard pattern for reordering

### Position Badge (#1, #2, etc.)
- Shows current position in list
- Position #1 highlighted in green
- Updates live as user drags

### Icons
- Each view has unique icon
- Helps visual scanning
- Consistent with menu icons

### Color Coding
- **Green**: Position #1 (default/favorite view)
- **Blue**: Accent color for interactive elements
- **Gray**: Secondary text and inactive elements

### Feedback
- Checkmark (✓) in menu shows current view
- Green badge shows default view in editor
- Position numbers update during drag

---

## User Interaction Flow

1. **Discovery**: User notices "Customize Order..." at bottom of menu
2. **Exploration**: Taps to open editor sheet
3. **Learning**: Sees instructions and visual layout
4. **Action**: Drags favorite view to top
5. **Confirmation**: Green highlight confirms it's now #1
6. **Saving**: Taps "Save" button
7. **Result**: Next time they open Schedule → favorite view appears!

---

## Accessibility Features

- ✅ VoiceOver friendly (drag handles and positions announced)
- ✅ Large touch targets (entire row is draggable)
- ✅ Clear visual hierarchy
- ✅ Descriptive labels
- ✅ Keyboard navigation support (macOS)

---

## Edge Cases Handled

1. **First Launch**: Uses default order (List first)
2. **App Update**: New views automatically appended
3. **Cancel**: Changes discarded if user doesn't save
4. **Reset**: One-tap restoration to default order
5. **Empty State**: Not possible (at least one view always present)

---

## Performance Notes

- Preferences load instantly from UserDefaults
- No network calls required
- Smooth drag animations
- Lightweight JSON persistence
- No impact on app launch time
