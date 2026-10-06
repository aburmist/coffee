# Coffee Taster for iPhone

Log a coffee by describing it in your own words: typed, spoken, or to Siri. Your
iPhone fills in the details on device, tells you what to change next time, and keeps
your history as CSV files in a folder you choose.

## What's in the app

| Tab | What it does |
|---|---|
| **Log** | Type or tap **Speak**, then **Fill in**. Apple Intelligence (on device) turns "Espresso, 18g in 36g out, 5 clicks, 28s, a bit sour, 4 stars" into a brew you can check before saving. **Same as last time** starts from your previous brew, so you only add how it tasted. |
| **Timer** | Step-by-step recipes (espresso, V60, AeroPress, French press, Clever, moka) scaled to your dose and ratio, with haptics at each step and a Live Activity on the Lock Screen and Dynamic Island. When you stop, **Log this brew** fills in method, dose, water and time. |
| **History** | Every brew, with search and a method filter. Each brew shows a **Next time** suggestion (e.g. "Grind 1 click finer → 5"), and **Brew again** starts from it with the suggested grind. |
| **Beans** | Your bags with days off roast, the best recipe so far and a rating-by-grind chart. **Scan the bag** reads the label with the camera. |
| **Settings** | Grinder (default Baratza Encore, 1–40), usual method, °F/°C, the sync folder, CSV import and sharing. |

**Siri** (also in Shortcuts and on the Action button):
- "Hey Siri, log a coffee in Coffee Taster" → Siri asks how it was → saved. Anything
  you don't mention (grind, dose…) is copied from your last brew of that method, and
  Siri reads back the next-time tip.
- "Hey Siri, start an espresso timer in Coffee Taster"

Without Apple Intelligence (simulator, older iPhones, or turned off) a rule-based
parser fills in what it can, and you complete the rest on the review screen.

## Run it on your iPhone (free Apple ID)

You need a Mac with **Xcode 26** or later and an iPhone on **iOS 26** or later (iPhone 16 ✓).

1. Install XcodeGen: `brew install xcodegen`
2. Generate the project and open it:
   ```sh
   cd ios
   xcodegen
   open CoffeeTaster.xcodeproj
   ```
3. Xcode → Settings → Accounts → add your Apple ID. This creates a **Personal Team**.
4. Select the **CoffeeTaster** target → Signing & Capabilities → Team: your Personal Team.
   Do the same for **CoffeeTasterWidgets** (the Live Activity).
5. On the iPhone: turn on **Developer Mode** (Settings → Privacy & Security) and
   **Apple Intelligence** (Settings → Apple Intelligence & Siri).
6. Plug in the iPhone, pick it as the run destination and press **Run** (⌘R).
   The first time, trust your certificate on the iPhone: Settings → General →
   VPN & Device Management.

With a free Apple ID the app stops launching after **7 days**. Press Run again to
renew it; your brews are kept.

**Keep your team after re-running XcodeGen.** `xcodegen` rewrites the project, which
clears the team you picked. To keep it, create `ios/Config/Local.xcconfig` (git-ignored):

```
DEVELOPMENT_TEAM = ABCDE12345
```

You can find your team ID in Xcode → Settings → Accounts → your Apple ID → the team.

**"Bundle identifier is not available".** Bundle IDs are unique across all Apple
accounts, and `com.coffee.CoffeeTaster` may be taken. Add a line like this to
`Local.xcconfig` and run `xcodegen` again:

```
BUNDLE_ID_PREFIX = com.coffee.yourname
```

## History sync

On first launch (or in Settings → **Choose sync folder…**) pick a folder, e.g.
**iCloud Drive → Coffee**. After every save, edit or delete the app rewrites:

- `coffee-brews.csv`: one row per brew
- `coffee-beans.csv`: one row per bag

iCloud Drive syncs them to your Mac, so you can open them in Numbers or Excel or
import them into Google Sheets. If the folder already has these files (a new phone, a
reinstall), they're merged in first. A copy is always in Files → On My iPhone →
Coffee Taster.

**Old Google Sheet data.** Download the sheet as CSV (File → Download →
Comma-separated values) and use Settings → **Import a CSV file…**. The old columns
are mapped automatically, including the temperature presets and ⭐️ ratings. Or fill
in the templates in [`../templates`](../templates).

The format is described in [`../PLAN.md`](../PLAN.md#6-csv-format-sync-and-backup).

## Code layout

```
ios/
├── project.yml            XcodeGen spec (app + Live Activity extension)
├── Config/Base.xcconfig   bundle ID prefix; includes your optional Local.xcconfig
├── CoffeeKit/             Swift package: all logic, no UI (tested on Linux and macOS)
│   ├── BrewTextParser     rule-based text → brew
│   ├── DialIn             next-time suggestions
│   ├── Recipes            timer recipes and steps
│   ├── CSV                sync format, old-sheet import, merging
│   └── …                  methods, grinders, flavors, units
├── CoffeeTaster/          the app
│   ├── AI/                Foundation Models extraction, bag-label reading
│   ├── Features/          Log, Timer, History, Beans, Settings
│   ├── Intents/           Siri / Shortcuts
│   ├── Models/            SwiftData models
│   ├── Speech/            mic dictation
│   └── Sync/              folder sync
├── CoffeeTasterWidgets/   Live Activity UI
└── Shared/                types used by both the app and the extension
```

Logic tests: `cd ios/CoffeeKit && swift test`. CI (`.github/workflows/ios.yml`) runs
them on Linux and macOS and builds the app for the iOS Simulator.
