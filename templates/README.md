# CSV templates for importing old brews

Coffee Taster for iOS syncs your history as two CSV files. If you fill in these
templates with your old data and put them in the app's sync folder, the app imports
them the first time you choose that folder.

- `coffee-brews.csv`: one row per brew. **Required.**
- `coffee-beans.csv`: one row per bag of beans. Optional.

Delete the example rows before importing. Keep the header row exactly as it is.
Save as CSV (UTF-8). Google Sheets: File → Download → Comma-separated values.

## Brew columns

Only `method` is required. Leave anything you don't know empty.

| Column | Meaning | Example |
|---|---|---|
| `id` | leave empty; the app creates one | |
| `date` | when you brewed it | `2024-09-15 08:30:00` (local time) |
| `bean_id` | leave empty | |
| `bean_name` | name of the bean; matched to `name` in `coffee-beans.csv`, or a new bean is created | `Ethiopia Guji` |
| `method` | `Espresso`, `Pour Over`, `AeroPress`, `French Press`, `Clever`, `Moka`, `Drip`, `Cold Brew` or `Other` (any capitalization) | `Pour Over` |
| `grinder` | grinder name | `Comandante` |
| `grind_setting` | number | `22` |
| `dose_g` | coffee, grams | `18` |
| `water_g` | water, grams | `300` |
| `yield_g` | espresso only: drink weight, grams | `36` |
| `temp_c` | water temperature, °C | `94` |
| `time_s` | brew time, seconds | `190` |
| `rating` | 1–5, half steps allowed | `4` or `3.5` |
| `extraction` | `sour`, `balanced` or `bitter` | `balanced` |
| `acidity` … `aftertaste` | 1–5 each | `4` |
| `flavors` | separated by `;` | `blueberry;floral` |
| `comment` | free text (put it in quotes if it contains a comma) | `Sweet and juicy` |
| `original_text` | leave empty | |

## Converting the old Google Sheet

The old web app's sheet has the columns `coffee_weight, coffee_grind, water_weight,
water_temperature, brew_time, brew_method, rating, comment, date`. In a copy of the
sheet, map them like this:

| Old column | New column | How |
|---|---|---|
| `date` | `date` | copy as is |
| `brew_method` | `method` | copy as is (`Aeropress` is fine) |
| `coffee_grind` | `grind_setting` | copy as is |
| `coffee_weight` | `dose_g` | copy as is |
| `water_weight` | `water_g`, or `yield_g` for espresso | copy as is |
| `brew_time` | `time_s` | copy as is |
| `water_temperature` | `temp_c` | convert, see formula below |
| `rating` (stars) | `rating` | convert, see formula below |
| `comment` | `comment` | copy as is |

Formulas for Google Sheets (assuming the old value is in cell `A2`):

- Temperature:
  `=SWITCH(A2, "175 Green", 79, "185 White", 85, "190 Oolong", 88, "200 FrenchPress", 93, "Boil", 100, "")`
- Stars to a number (each ⭐️ is two characters in Sheets):
  `=LEN(A2)/2`

Check a few converted rows by eye before importing.
