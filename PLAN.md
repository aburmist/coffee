# Coffee Taster — iOS App Plan

Goal: **the best app for tasting and dialing in coffee at home.** You describe what
you brewed and how it tasted, in your own words. The app turns that into a structured
record, links it to the bag of beans, tells you what to change next time, and keeps
your history synced as a file you own.

It is a native SwiftUI app for iPhone. It replaces the original Streamlit web app,
which stays in git history (last commit before removal: `4ef98e1`).

Status: **draft for review**. Nothing below is built yet.

---

## 1. Product principles

1. **Logging takes seconds.** Type or dictate one sentence and the app fills in the
   rest. Every field is optional except the method.
2. **Tasting first, not just numbers.** The value comes from linking *what you did*
   (dose, grind, time) to *how it tasted* (sour, sweet, juicy, bitter), per bean.
3. **Tell me what to change.** After every brew there is a concrete suggestion for
   the next one ("a bit sour → grind 2 steps finer").
4. **Private and offline.** On-device AI only: no accounts, no API keys, no server.
5. **Your data is yours.** History is written as a plain CSV to a folder you choose.
6. **Free to run.** Everything works with a free Apple ID on your own iPhone.

---

## 2. Platform and tech

| Area | Choice |
|---|---|
| Target | iOS 26+, iPhone. Tested on **iPhone 16** (Apple Intelligence capable). |
| UI | SwiftUI |
| Storage | SwiftData (on the phone) |
| Text → structured brew | **Foundation Models** (Apple's on-device model) with guided generation (`@Generable`) |
| Fallback when the model is unavailable | rule-based parser (simulator, Apple Intelligence off) |
| Voice | keyboard dictation; in-app mic button with **SpeechAnalyzer** later |
| Label scanning | **Vision** text recognition + Foundation Models to sort the text into fields |
| Charts | Swift Charts |
| Siri / Shortcuts / widgets | App Intents, WidgetKit |
| Brew timer on the Lock Screen | ActivityKit (Live Activity) |
| Sync | CSV in a user-chosen folder (iCloud Drive or another Files provider) |
| Tests | Swift Testing |
| Project file | XcodeGen (`project.yml`); the `.xcodeproj` is generated and git-ignored |
| Bundle ID | `com.coffee.CoffeeTaster`, set once in `project.yml` |

**Code split:** all the pure logic (models' value types, ratio math, dial-in rules,
fallback parser, CSV read/write, unit conversion) lives in a local Swift package,
`CoffeeKit`, which has no UI and no Apple-only frameworks. The app target holds the
UI and the Apple frameworks. Benefits:
- `swift test` runs the logic tests in seconds, on macOS **and Linux**. That means
  the logic can be checked on every commit, even from a non-Mac environment.
- The app target stays small and focused on UI.

---

## 3. Repository layout

```
coffee/
├── README.md                 # what it is, how to build and run on your iPhone
├── PLAN.md                   # this file
├── LICENSE
├── project.yml               # XcodeGen spec
├── CoffeeTaster/             # app target (SwiftUI, SwiftData, Apple frameworks)
│   ├── App/
│   ├── Features/             # Log, Review, Beans, History, DialIn, Timer, Settings, Sync
│   ├── AI/                   # Foundation Models extraction
│   └── Resources/            # assets, app icon (from the old logo)
├── CoffeeTasterWidgets/      # widget + Live Activity extension (later phase)
├── CoffeeKit/                # Swift package: pure logic + tests
│   ├── Package.swift
│   ├── Sources/CoffeeKit/
│   └── Tests/CoffeeKitTests/
└── .github/workflows/ci.yml  # Linux: swift test on CoffeeKit; macOS: build + test the app
```

Removed from the repo: `coffee.py`, `test_coffee.py`, `requirements.txt`,
`.streamlit/`, `.devcontainer/` (Python-only). The logo moves into the app's assets.

---

## 4. Data model

**Bean** (a bag of coffee)
- name, roaster, origin (country / region / farm), process (washed, natural, honey,
  anaerobic, other), varietal, roast level (light / medium / dark)
- roast date → shown as "12 days off roast" on every brew
- roaster's tasting notes (from the bag), photo of the bag, finished yes/no

**Grinder**
- name, setting range and step (e.g. Comandante 0–40 clicks, Niche 0–50, step 0.5)
- one default grinder in Settings

**Brew**
- date, bean (optional), method, grinder + grind setting
- dose (g), water (g) *or* espresso yield (g), water temperature (stored in °C),
  brew time (s)
- **Taste**
  - overall rating, 1–5 with half steps
  - extraction feel: sour / balanced / bitter (plus "weak" and "harsh" as extra flags)
  - optional 1–5 scales: acidity, sweetness, body, bitterness, aftertaste
  - flavor tags from a fixed list based on the SCA flavor wheel
    (e.g. blueberry, citrus, chocolate, caramel, floral, nutty …)
- comment, the original text you typed, optional photo of the cup

**Methods:** Espresso, Pour Over, AeroPress, French Press, Clever, Moka, Drip,
Cold Brew, Other. Each method has a default ratio and temperature (taken from the
old web app's ratios: Espresso 1:2, AeroPress 1:12.5, Pour Over 1:17, Clever 1:15,
French Press 1:15, Moka 1:7).

**Settings:** °C/°F, grams/ounces, default grinder, sync folder.

---

## 5. Features by phase

### Phase 0 — Clean slate
- Remove the web app files; update README and `.gitignore` for Xcode.
- `project.yml`, an app that launches with an empty tab layout, the `CoffeeKit`
  package with one passing test, and a placeholder app icon from the old logo.
- CI: `swift test` for `CoffeeKit` on Linux, plus `xcodegen` + `xcodebuild build
  test` on a macOS runner. CI is how compile errors are caught before you pull.

### Phase 1 — MVP: log a brew and see it
1. **Log screen.** One text box ("V60, Ethiopia Guji, 18g, 300g at 94°, grind 22,
   3:10, sweet and juicy but a bit sour, 4 stars") with dictation, plus a **"Same as
   last time"** button that copies the previous brew so you only change what's new.
2. **On-device extraction.** `@Generable` types turn the text into a draft brew:
   numbers with unit handling (3:10 → 190 s, 94° → °C), method, a match against your
   existing beans by name, extraction feel, flavor tags from the fixed list.
   Anything not mentioned stays empty instead of being guessed. If the model isn't
   available, the fallback parser runs.
3. **Review screen.** A native form showing the draft, with fields the model filled
   marked so you can check them. Ratio shown live ("1:16.7 · Pour Over target 1:17").
4. **Beans.** Add a bean manually; choose it on a brew; see days off roast.
5. **History.** A list of brews, newest first, with search; tap to edit, swipe to delete.

### Phase 2 — History you own: folder sync + import
- **Pick a sync folder once** (e.g. iCloud Drive → Coffee). After every save, edit or
  delete, the app rewrites `coffee-brews.csv` and `coffee-beans.csv` there. iCloud
  Drive syncs them to your Mac by itself; nothing to export or upload.
- **Import / restore** from those CSVs (merging by `id`), for a new phone or a
  reinstall.
- **Import the old Google Sheet** (File → Download → CSV): its columns are mapped
  automatically, including the old temperature presets
  (175 Green → 79 °C, 185 White → 85 °C, 190 Oolong → 88 °C, 200 FrenchPress → 93 °C,
  Boil → 100 °C) and star ratings.
- A copy of the CSVs is always in the app's own Documents folder, visible in the
  Files app under "On My iPhone".
- Sync is one-way (phone → file). Free Apple IDs can't use iCloud/CloudKit directly;
  writing to a folder you picked needs no special permission.

### Phase 3 — Tasting and dial-in (the core of "best app")
- **Dial-in suggestions** after each brew, from well-known extraction rules
  (sour/weak → finer, hotter or longer; bitter/harsh → coarser, cooler or shorter;
  thin → higher dose). Each suggestion is specific to the method and your grinder's
  step size ("grind 2 clicks finer → 20"). The rules live in `CoffeeKit` and are
  unit-tested. The on-device model is only used to phrase a short explanation.
- **Per-bean page:** all brews of that bean, the **best recipe so far**, a chart of
  rating against grind setting, and how the taste changed with days off roast.
- **Taste profile:** the five 1–5 scales and flavor tags shown as a small radar
  chart, compared with the roaster's notes from the bag.
- **Flavor wheel picker** for adding tags by hand.

### Phase 4 — Brew guide and timer
- Recipes per method with steps (e.g. Pour Over: bloom 50 g for 45 s, pour to 180 g,
  pour to 300 g, drawdown), scaled to your dose and ratio.
- A timer that moves through the steps, with haptics at each one. It runs as a
  **Live Activity** on the Lock Screen and Dynamic Island while you pour.
- When the timer stops, the Log screen opens with method, dose, water and time
  already filled in; you only add the taste.
- Save your own recipes; "brew again" from any past brew.

### Phase 5 — Native extras
- **Scan a coffee bag** with the camera: Vision reads the label, the on-device model
  sorts it into roaster, name, origin, process, roast date and tasting notes.
- **Siri and Shortcuts:** "Log a coffee", "Start a pour-over timer", "What was my best
  brew of [bean]?".
- **Home-screen and Lock Screen widgets:** last brew, the current bean's days off
  roast, a quick "Log" button.
- **Insights:** favorite origins and processes, rating trends, your coffee per week.
- In-app mic button using SpeechAnalyzer, so logging works hands-free while brewing.

### Later / maybe
- iCloud/CloudKit sync between devices and an Apple Watch timer (need the paid
  developer account).
- Sharing a recipe as a link or card.
- Caffeine logging to Apple Health.

---

## 6. CSV format (sync and backup)

`coffee-brews.csv`, one row per brew, UTF-8 with a header row:

`id, date, bean_id, bean_name, method, grinder, grind_setting, dose_g, water_g,
yield_g, temp_c, time_s, rating, extraction, acidity, sweetness, body, bitterness,
aftertaste, flavors, comment, original_text`

- `date` is ISO 8601 with the time zone (`2026-10-06T08:15:00-07:00`).
- `flavors` is a `;`-separated list inside one cell.
- Units are always grams and °C in the file, whatever the app's display setting.

`coffee-beans.csv`: `id, name, roaster, origin, process, varietal, roast_level,
roast_date, roaster_notes, finished`.

---

## 7. Testing

- **`CoffeeKit` unit tests** (run on Linux and macOS in CI): ratio math, unit
  conversion, time parsing ("3:10", "190s", "3 min"), dial-in rules for every
  method and taste combination, the fallback parser on a table of sample sentences,
  CSV write → read round trip, import of a real old Google Sheet export.
- **App tests** on the macOS runner: SwiftData model, view models.
- **Extraction check on your iPhone:** a debug-only screen that runs a fixed set of
  sample sentences through the on-device model and shows the results side by side
  with what's expected. CI can't run the model, so this is how prompt changes are
  checked.
- **Manual smoke test** on the iPhone before each phase is called done.

---

## 8. Running on your iPhone (free Apple ID)

1. Install Xcode 26+ and XcodeGen (`brew install xcodegen`).
2. Xcode → Settings → Accounts → add your Apple ID (this creates a "Personal Team").
3. `xcodegen && open CoffeeTaster.xcodeproj`, then choose your Personal Team under
   Signing.
4. On the iPhone: turn on **Developer Mode** (Settings → Privacy & Security) and
   **Apple Intelligence** (Settings → Apple Intelligence & Siri).
5. Plug in the iPhone and press Run. The first time, trust the developer certificate:
   Settings → General → VPN & Device Management.
6. The app stops launching after 7 days. Press Run again to renew; your data is kept.

If Xcode says the bundle ID `com.coffee.CoffeeTaster` is "not available" (bundle IDs
are unique across all Apple accounts), change `BUNDLE_ID_PREFIX` in `project.yml`,
for example to `com.coffee.<yourname>`, and run `xcodegen` again.

---

## 9. Decisions

- iOS app only. The web app is removed and kept only in git history.
- No OpenAI or any other cloud AI: Apple's on-device model only.
- Bundle ID `com.coffee.CoffeeTaster`.
- Google Sheets is not required. History syncs as CSV files in a folder you choose;
  the old sheet can be imported once.
- Test device: iPhone 16.

## 10. Open questions

1. **Your gear:** which grinder(s) and brew methods do you use most? This sets the
   default grind scale and which recipes come first.
2. **Units:** °C or °F by default?
3. **Order:** is this phase order right, or should the brew timer (Phase 4) come
   before tasting and dial-in (Phase 3)?
