# CLUBVMK Rarity Curator

A shared web tool for tagging which MyVMK items are rare. You and a friend open
the same page, and edits sync **live** between you through a free Supabase
database. Your collector bot then pulls the same shared list.

**Live page:** https://bsims-codes.github.io/clubvmk-curator/

---

## One-time setup (do this once)

### 1. Create a free Supabase project
1. Go to <https://supabase.com> → sign in → **New project**.
2. Give it a name + database password (any), pick a region, create it. Wait ~1 min.

### 2. Create the shared table
1. In your project: **SQL Editor** → **New query**.
2. Open `supabase-setup.sql` from this repo, copy everything, paste it, click **Run**.

### 3. Connect the page to your project
1. In Supabase: **Project Settings → API**. Copy the **Project URL** and the **anon public** key.
2. Edit `config.js` in this repo and paste them in:
   ```js
   window.SUPABASE_URL = "https://abcdefgh.supabase.co";
   window.SUPABASE_ANON_KEY = "eyJhbGciOi...";   // the long anon public key
   ```
3. Commit/push `config.js`. (These two values are safe to be public — that's what the anon key is for.)

Now open the live page. The status pill at the top should say **● live sync on**.
Share the page URL with your friend — you'll see each other's changes appear in real time.

---

## How you both use it
- **Search** an item family (e.g. `magic`, `wings`, `mickey ears`).
- Set a tier per item with the dropdown, or use **Set all shown → Apply to filtered** to tag a whole search at once.
- Everything auto-saves to the shared database — no export needed for collaborating.
- The counts at the top show how many items are in each tier.

## Getting the rarities into the bot
On the bot laptop, run (in the CLUBVMKBOT folder):
```bash
python pull_rarity.py
```
It fetches the current shared list from Supabase and updates the bot's catalog.
Then restart the bot. (Setup for `pull_rarity.py` is in the CLUBVMKBOT README.)

The **⬇ Export** button still works if you ever want a plain `rarity_overrides.json` file as a backup.

---

## Files
| File | Purpose |
|------|---------|
| `index.html` | The curator page (loads images + syncs via Supabase) |
| `config.js` | Your Supabase URL + anon key |
| `supabase-setup.sql` | Run once to create the shared table |
| `items.json` | The item catalog (name, category, image, baseline rarity) |
| `assets/items/` | All item images |
| `.nojekyll` | Tells GitHub Pages to serve the assets folder as-is |
