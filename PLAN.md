# Coffee Taster — iOS App Plan

Goal: **the best app for tasting and dialing in coffee at home.** You describe what
you brewed and how it tasted, in your own words. The app turns that into a structured
record, links it to the bag of beans, tells you what to change next time, and keeps
your history synced as a file you own.

It is a native SwiftUI app for iPhone, in its **own new repository**. The Streamlit
web app stays where it is (this repo, deployed on Streamlit Community Cloud) and is
not changed.

Status: **first version built** in [`ios/`](ios/README.md), covering Phases 0–3 and
the bag scan from Phase 4. It lives in the web repo for now and moves to its own repo
once that exists. Not built yet: home-screen widgets, insights, and "What was my best
brew of [bean]?" in Siri. The in-app mic uses `SFSpeechRecognizer` (on device) rather
than `SpeechAnalyzer`.

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
| Voice | in-app mic button with **SpeechAnalyzer** (on-device); Siri via App Intents; keyboard dictation |
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

## 3. Repository layout (new repo)

```
coffee-taster-ios/
├── README.md                 # what it is, how to build and run on your iPhone
├── PLAN.md                   # this file (moves here from the web repo)
├── LICENSE
├── project.yml               # XcodeGen spec
├── CoffeeTaster/             # app target (SwiftUI, SwiftData, Apple frameworks)
│   ├── App/
│   ├── Features/             # Log, Review, Beans, History, Timer, DialIn, Settings, Sync
│   ├── Intents/              # Siri / Shortcuts (App Intents)
│   ├── AI/                   # Foundation Models extraction
│   └── Resources/            # assets, app icon (from the old logo)
├── CoffeeTasterWidgets/      # Live Activity for the brew timer (+ widgets later)
├── CoffeeKit/                # Swift package: pure logic + tests
│   ├── Package.swift
│   ├── Sources/CoffeeKit/
│   └── Tests/CoffeeKitTests/
├── templates/                # CSV templates for a one-time import of old data
└── .github/workflows/ci.yml  # Linux: swift test on CoffeeKit; macOS: build + test the app
```

The CSV templates are already in the web repo under `templates/` so you can prepare
your old data now; they move to the new repo in Phase 0.

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

Priorities, from you: **logging, Siri voice input, the brew timer, and folder sync
from day one.** Those make up Phases 1 and 2. Tasting depth and extras come after.

### Phase 0 — New repo and skeleton
- Create the new repo; move `PLAN.md` and `templates/` into it.
- `project.yml`, an app that launches with an empty tab layout (Log, History, Beans,
  Settings), the `CoffeeKit` package with one passing test, and a placeholder app
  icon from the old logo.
- CI: `swift test` for `CoffeeKit` on Linux, plus `xcodegen` + `xcodebuild build
  test` on a macOS runner. CI is how compile errors are caught before you pull.

### Phase 1 — Log a brew, keep the history synced (MVP)
1. **Log screen.** One text box ("V60, Ethiopia Guji, 18g, 300g at 94°, grind 22,
   3:10, sweet and juicy but a bit sour, 4 stars"), a **mic button** for speaking
   instead of typing (SpeechAnalyzer, on-device), and a **"Same as last time"**
   button that copies the previous brew so you only change what's new.
2. **On-device extraction.** `@Generable` types turn the text into a draft brew:
   numbers with unit handling (3:10 → 190 s, 94° → °C), method, a match against your
   existing beans by name, extraction feel, flavor tags from the fixed list.
   Anything not mentioned stays empty instead of being guessed. If the model isn't
   available, the fallback parser runs.
3. **Review screen.** A native form showing the draft, with fields the model filled
   marked so you can check them. Ratio shown live ("1:16.7 · Pour Over target 1:17").
4. **Beans.** Add a bean manually; choose it on a brew; see days off roast.
5. **History.** A list of brews, newest first, with search; tap to edit, swipe to delete.
6. **Folder sync.**
   - On first launch, the app asks you to pick a sync folder (e.g. iCloud Drive →
     Coffee). You can skip this and do it later in Settings.
   - After every save, edit or delete, the app rewrites `coffee-brews.csv` and
     `coffee-beans.csv` there. iCloud Drive syncs them to your Mac by itself;
     nothing to export or upload.
   - **Import:** if the folder already has those files (a new phone, a reinstall, or
     the template you filled in from the old Google Sheet), the app offers to import
     them, merging by `id`.
   - A copy is always in the app's own Documents folder, visible in the Files app
     under "On My iPhone".
   - Sync is one-way (phone → file). Free Apple IDs can't use iCloud/CloudKit directly;
     writing to a folder you picked needs no special permission.

### Phase 2 — Siri and the brew timer
- **"Hey Siri, log a coffee in Coffee Taster."** Siri asks "How was it?", you answer
  in one sentence, and Siri turns your speech into text. The app extracts the brew,
  shows a confirmation card inside Siri ("Pour Over · 18 g → 300 g · 4★ — Save?"),
  and saves it. You never open the app. Missing fields can be filled in later.
- **"Hey Siri, start a pour-over timer."** Starts the brew timer for that method.
- **Brew timer.** Recipes per method with steps (e.g. Pour Over: bloom 50 g for 45 s,
  pour to 180 g, pour to 300 g, drawdown), scaled to your dose and ratio. Haptics at
  each step. It runs as a **Live Activity** on the Lock Screen and Dynamic Island.
- **Timer → log.** When the timer stops, the Log screen opens with method, dose,
  water and time already filled in; you only say or type how it tasted.
- All of these also appear in the Shortcuts app and as Action button options
  (iPhone 16), so one press can start the timer.

### Phase 3 — Tasting and dial-in
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
- Save your own timer recipes; "brew again" from any past brew.

### Phase 4 — Extras
- **Scan a coffee bag** with the camera: Vision reads the label, the on-device model
  sorts it into roaster, name, origin, process, roast date and tasting notes.
- **Home-screen and Lock Screen widgets:** last brew, the current bean's days off
  roast, a quick "Log" button.
- **Insights:** favorite origins and processes, rating trends, coffee per week.
- More Siri questions: "What was my best brew of [bean]?"

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

- `date` is ISO 8601 with the time zone (`2026-10-06T08:15:00-07:00`). On import,
  `2024-09-15 08:30:00` (the old sheet's format, read as local time) also works.
- On import, only `method` is required. An empty `id` gets a new one.
- `flavors` is a `;`-separated list inside one cell.
- Units are always grams and °C in the file, whatever the app's display setting.

`coffee-beans.csv`: `id, name, roaster, origin, process, varietal, roast_level,
roast_date, roaster_notes, finished`.

---

## 7. Testing

- **`CoffeeKit` unit tests** (run on Linux and macOS in CI): ratio math, unit
  conversion, time parsing ("3:10", "190s", "3 min"), dial-in rules for every
  method and taste combination, the fallback parser on a table of sample sentences,
  CSV write → read round trip, importing the filled-in templates.
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

- Separate new repo for the iOS app. The Streamlit app stays deployed and unchanged.
- No OpenAI or any other cloud AI: Apple's on-device model only.
- Bundle ID `com.coffee.CoffeeTaster` (override with `BUNDLE_ID_PREFIX` in `Config/Local.xcconfig`).
- Folder sync is part of the MVP. No Google Sheets connection; the old sheet's CSV
  download imports directly.
- Top priorities: logging, Siri voice logging, brew timer.
- Gear: Baratza Encore (1–40, one click per step) as the default grinder; espresso as
  the usual method (around 5–6 clicks); dial-in moves espresso 1 click at a time and
  filter methods 2.
- °F by default (stored as °C in the CSV files).
- Test device: iPhone 16.

## 10. Open questions

1. **New repo**: create it (suggested name `coffee-taster-ios`) and give the Claude
   GitHub App access, then the `ios/` folder moves there with its history.
