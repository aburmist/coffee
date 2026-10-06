# Coffee Taster for iOS — Plan

A native SwiftUI version of the Coffee Taster web app (`coffee.py`). You describe a
brew in plain words, the phone turns it into a structured tasting record, you check
it, and it is saved. Everything that used OpenAI or LangChain is replaced with
frameworks built into iOS. No API keys, no server, and extraction works offline.

Status: **draft for review**. Nothing below is built yet.

---

## 1. Goals and non-goals

**Goals**
- Same core flow as the web app: free text → extracted fields → review form → save.
- Use Apple's on-device model for extraction. No OpenAI key, no network needed to log a brew.
- Local-first: the phone keeps the full history even with no connection.
- Your history is kept automatically as a CSV in a folder you choose (iCloud Drive or
  similar), so you can open it on a Mac or in a spreadsheet without exporting anything.
- Run on your own iPhone with a **free Apple ID** (no paid developer account).

**Non-goals (for now)**
- App Store or TestFlight distribution. Both need the paid account.
- Android, iPad-specific layouts, Apple Watch.
- Changing the web app, beyond the folder move in Phase 0.

---

## 2. Repository layout

Keep **one repo** with the two apps side by side. They share the data format (the
same CSV / sheet columns), so it helps to change them in the same place. They share no code.

```
coffee/
├── README.md              # overview + links to each app
├── LICENSE
├── web/                   # existing Streamlit app (moved, unchanged)
│   ├── coffee.py
│   ├── test_coffee.py
│   ├── requirements.txt
│   ├── coffee_tasting_logo.png
│   └── .streamlit/config.toml
├── ios/
│   ├── PLAN.md            # this file
│   ├── README.md          # build & run instructions
│   ├── project.yml        # XcodeGen spec → generates CoffeeTaster.xcodeproj
│   ├── CoffeeTaster/      # app sources
│   └── CoffeeTasterTests/ # unit tests
├── .devcontainer/         # updated to run web/coffee.py
└── .github/workflows/
    └── ios.yml            # build + test on a macOS runner
```

Effects of moving the web app into `web/`:
- `.devcontainer/devcontainer.json`: change the install and run commands to `web/`.
- Streamlit Community Cloud (if it is deployed there): change the main file path to `web/coffee.py`.
  Streamlit reads `.streamlit/` from the working directory, so run it as `cd web && streamlit run coffee.py`.
- `.streamlit/secrets.toml` (git-ignored, on your machine) moves to `web/.streamlit/`.

**Why XcodeGen:** the `.xcodeproj` file is large, generated XML that is easy to break
by hand and produces messy merge conflicts. A short `project.yml` is easy to review.
You run `brew install xcodegen && xcodegen` once, then open the project. The generated
`.xcodeproj` is git-ignored.

---

## 3. Requirements

| | Requirement | Why |
|---|---|---|
| Mac | Xcode 26+ | Foundation Models framework, iOS 26 SDK |
| iPhone | iOS 26+, **Apple Intelligence capable** (iPhone 15 Pro / Pro Max, any iPhone 16 or 17) with Apple Intelligence turned on | on-device language model |
| Account | Free Apple ID signed into Xcode | personal-team signing; reinstall every 7 days |
| Simulator | Runs the app. The on-device model works there only if the Mac itself runs macOS 26 with Apple Intelligence on | for UI work without a phone |

On older iPhones, or with Apple Intelligence turned off, the app still works. It
falls back to the rule-based parser (Phase 1) and the manual form.

---

## 4. Features by phase

### Phase 0 — Repo restructure
- Move the web app into `web/` and update the devcontainer and README.
- Add the `ios/` skeleton: `project.yml`, an empty app that launches, and a test target.
- Add the GitHub Actions workflow: `xcodegen` → `xcodebuild build test` on a macOS runner.
  This is how compile errors get caught before you pull, since the iOS code is written
  outside Xcode.

### Phase 1 — MVP: log a brew (feature parity with the web app)
1. **Data model** (`SwiftData`), `Brew`:
   `grindSize` (1–40), `method`, `coffeeGrams`, `waterGrams`, `waterTemperature`,
   `brewSeconds`, `rating` (1–5), `comment`, `date`, `originalText`.
   `method` and `waterTemperature` are enums with the same values as the web app
   (`Espresso … Drip`, `175 Green … Boil`), so rows stay compatible with the sheet.
2. **Describe screen**: a multiline text field with the same example hint as the web
   app. Voice input comes from the keyboard's built-in dictation mic, so no extra code
   or permissions are needed.
3. **On-device extraction** with the **Foundation Models** framework:
   - A `@Generable struct BrewDraft` with `@Guide` constraints (grind `1...40`,
     method and temperature as enums, rating `1...5`). Guided generation returns a
     typed struct. That removes the fragile line-by-line parsing in `coffee.py`.
   - Any field the text doesn't mention is left optional (`nil`) instead of guessed.
   - Check `SystemLanguageModel.default.availability` first. If the model is
     unavailable, use the fallback.
   - **Fallback parser:** a small regex-based parser for the common patterns
     ("18g", "size 4", "50 sec", "4 stars", method names). It is unit-tested and also
     covers the simulator and older phones.
4. **Review screen**: a native `Form` with pickers for method, temperature and rating,
   steppers or number fields for grind, weights and time, and a comment field.
   Fields the model left empty are highlighted.
5. **Brew-ratio hint**: a port of `calc_brew_ratio` that shows live on the review
   screen ("Pour Over 1:17 → 306 g water for 18 g coffee") instead of after saving.
6. **Save + confirmation**: saves the brew and shows a summary card. A "Start over"
   button clears the screen (this fixes the web app's broken button).

### Phase 2 — History
- A list of past brews, newest first, with swipe to delete and tap to edit.
- Filter by method and by rating.
- Simple stats with **Swift Charts**: average rating per method, and rating against grind size.
- "Brew again": start a new log prefilled from a past brew.

### Phase 3 — Native conveniences
- **Siri and Shortcuts** (App Intents): "Log a coffee in Coffee Taster" opens the
  describe screen. A second intent saves a brew straight from spoken text.
- **Brew timer**: a stopwatch on the describe screen that fills in brew time.
  A Live Activity / Dynamic Island version can come later.
- **Coffee bag scan**: the camera plus Vision text recognition reads the roaster and
  bean name from the bag label into optional new fields (`beanName`, `roaster`).
- **One-off export**: share the CSV through the share sheet (AirDrop, Mail, …) for
  the times you want to send it somewhere outside the sync folder.

### Phase 4 — Folder sync for history (no upload step)
The aim is a history file that stays up to date by itself, with no paid account and
no server.

- **Pick a sync folder once** in Settings, using the system folder picker. Choose a
  folder in **iCloud Drive** (or any Files provider such as Google Drive, Dropbox or
  OneDrive). The app keeps a security-scoped bookmark, so it can write there later
  without asking again.
- **Automatic CSV**: after every save, edit or delete, the app rewrites
  `coffee-log.csv` in that folder, using file coordination for safe writes. iCloud
  Drive then syncs the file to your Mac and iCloud.com by itself. You can open it in
  Numbers or Excel, or import it into Google Sheets.
- **Import / restore**: read a `coffee-log.csv` back in, merging rows by `id`. This
  covers a new phone, deleting and reinstalling the app, and loading your **existing
  Google Sheet history** (File → Download → CSV).
- **Status line** in Settings: "Last synced 2 min ago · 143 brews". If the folder
  becomes unavailable, the app shows a warning; brews are still saved on the phone,
  and the CSV is caught up on the next save.
- **Local copy**: the app's Documents folder is visible in the Files app
  ("On My iPhone → Coffee Taster") and holds the same CSV, so a copy is there even
  before you pick a folder.

Why not iCloud/CloudKit sync directly: both need the iCloud entitlement, which free
personal teams can't use. Writing to a folder you picked in iCloud Drive needs no
entitlement, because the Files app's provider does the syncing.

Note: this is one-way (phone → file). Editing the CSV on the Mac doesn't change the
app until you import it. Two-way merge can come later if needed.

### Later / maybe
- Home-screen widget (last brew, quick "log" button). Sharing data between the app
  and a widget needs App Groups. Check whether a free personal team allows that.
- Full iCloud/CloudKit sync between devices: needs the paid account.
- Google Sheets live sync (Apps Script endpoint), if the CSV turns out not to be enough.
- Apple Health caffeine logging.

---

## 5. CSV format

The CSV uses the web app's Google Sheet columns in the same order, so old sheet
exports import directly. Two columns are added at the end: `id` (UUID, used to merge
on import) and `original_text`. When importing old rows that have no `id`, the app
creates one.

| CSV column | iOS `Brew` | Notes |
|---|---|---|
| `coffee_weight` | `coffeeGrams` | Int |
| `coffee_grind` | `grindSize` | Int 1–40 |
| `water_weight` | `waterGrams` | Int |
| `water_temperature` | `waterTemperature.rawValue` | e.g. `"200 FrenchPress"` |
| `brew_time` | `brewSeconds` | Int |
| `brew_method` | `method.rawValue` | e.g. `"Pour Over"` |
| `rating` | `rating` → `"⭐️" × n` | stored as Int, written as stars |
| `comment` | `comment` | |
| `date` | `date` | `yyyy-MM-dd HH:mm:ss`, local time |
| `id` | `id` | UUID (new) |
| `original_text` | `originalText` | what you typed (new) |

---

## 6. Testing

- **Unit tests (Swift Testing)**, run in CI:
  - brew-ratio math for every method
  - the fallback parser against a table of sample sentences (including the README example)
  - CSV write → read round trip, plus importing a real export of the old Google Sheet
- **Extraction checks on the device**: a debug-only screen that runs the sample
  sentences through the on-device model and shows the results. The model only runs
  on real hardware, so CI can't run this.
- **Manual smoke test** before each phase is marked done: log, edit and delete a brew
  on your iPhone.

---

## 7. Running on your iPhone (free Apple ID)

1. Xcode → Settings → Accounts → add your Apple ID (this creates a "Personal Team").
2. `cd ios && xcodegen && open CoffeeTaster.xcodeproj`
3. Choose your Personal Team under Signing. The bundle ID is `com.coffee.CoffeeTaster`.
   Bundle IDs must be unique across all Apple accounts. If Xcode says the ID is "not
   available", change `BUNDLE_ID_PREFIX` in `project.yml` (for example to
   `com.coffee.<yourname>`) and run `xcodegen` again.
4. Plug in your iPhone and turn on **Developer Mode** (Settings → Privacy & Security).
   Run the app.
5. On the iPhone, trust the developer certificate the first time: Settings → General →
   VPN & Device Management.
6. The app stops launching after 7 days. Press Run in Xcode again to renew it. Your
   data is kept.

---

## 8. Decisions

- Bundle ID: `com.coffee.CoffeeTaster`, set once in `project.yml` so it's easy to change.
- Google Sheets is not required. History lives on the phone and is synced as a CSV
  through a folder you choose (Phase 4).

## 9. Open questions

1. **Which iPhone** will you test on? This confirms Apple Intelligence support.
2. **Is the web app deployed** on Streamlit Community Cloud? If so, its main-file path
   has to change in Phase 0.
3. **Phase 3 priorities**: which of Siri, the timer and the bag scan matter most?
4. **Move folder sync earlier?** If historical tracking matters most, Phase 4 can
   ship right after Phase 1, before history and charts.
