# Test Prep & Kunskapsäventyret — notes for Claude

A self-hosted study app for school children, built on the Swedish curriculum (Lgr22). Two apps run
from one small Node server with **no dependencies**:

- **Test Prep** (`index.html`, port 8787) — flashcards, quiz, match terms, and Write & Review
  (answers graded by Claude).
- **Kunskapsäventyret** (`adventure/index.html`, port 8788) — an adventure game for younger children:
  find hidden animals, answer their questions, reach the castle. Same question packs.

Most people who open this repo with Claude want one of three things: **set it up on their computer**,
**add question packs for their child's grade**, or **change something in the game**. Each is below.

---

## 1. Setting it up for someone

The goal: the app running in their browser, with as little effort for them as possible. They may not
be developers — explain in plain words, and do the steps for them where you can.

1. **Node.js 18 or newer.** Check with `node --version`. If it's missing or older, help install the
   LTS version:
   - macOS: `brew install node` if Homebrew is there, otherwise the installer from https://nodejs.org/
   - Windows: `winget install OpenJS.NodeJS.LTS`, or the installer from https://nodejs.org/
   - Linux: the distribution's package manager, or `nvm install --lts`
2. **No `npm install`.** The server uses only Node's built-in modules.
3. **Start it** from the repo folder: `node server.js` (run it in the background if you need the
   terminal). It prints both addresses.
4. **Check it works:**
   ```bash
   curl -s http://localhost:8787/api/packs | head -c 200   # lists the question packs
   curl -s http://localhost:8788/ | grep -o "<title>[^<]*"  # Kunskapsäventyret
   ```
5. **Tell them where to go:** http://localhost:8787 (Test Prep) and http://localhost:8788
   (Kunskapsäventyret). Progress is saved in the browser. `Ctrl+C` stops the server; `node server.js`
   starts it again.

### Optional: a Claude API key (for Write & Review)

Everything works without a key; only Write & Review (and the adventure's written final question) need
one. The key is theirs — reviews are billed to their Anthropic account (Haiku, a fraction of a cent
each). Keys are created at https://console.anthropic.com/settings/keys (needs credit on the account).

- **Don't ask them to paste the key into the chat.** Create `config.json` next to `server.js` with a
  placeholder and let them put the key in themselves:
  ```json
  { "ANTHROPIC_API_KEY": "sk-ant-PASTE-YOUR-KEY-HERE" }
  ```
  If they paste it into the chat anyway, write it only into `config.json` — nowhere else.
- `config.json` is git-ignored. Never commit it, never put the key in any other file.
- Restart the server. It works when the startup warning `No ANTHROPIC_API_KEY set` is gone and
  `curl -s http://localhost:8787/api/config` says `{"hasClaude":true}`.

### Optional: their own weather (adventure themes)

The adventure's scenery follows the season, weather and time of day for one place — central Stockholm
by default. Ask which town they live in and add rough coordinates (two decimals — about 1 km, enough
for weather and no more precise than needed) to `config.json`:
```json
{ "ANTHROPIC_API_KEY": "…", "WEATHER_LAT": 57.71, "WEATHER_LON": 11.97 }
```
Weather comes from Open-Meteo (free, no key), cached 15 minutes. Check with
`curl -s http://localhost:8788/api/theme`.

### Other things they may ask for

- **Other devices on the same Wi-Fi** (a child's tablet): the server listens on all interfaces, so
  find the computer's local IP (`ipconfig getifaddr en0` on macOS, `ipconfig` on Windows,
  `hostname -I` on Linux) and give them `http://<ip>:8787` and `:8788`. Mention there is no login —
  anyone on that network can use it.
- **Other ports:** `PORT=9000 node server.js` (the adventure goes on `PORT + 1`, or `ADVENTURE_PORT`).
- **Docker:** `echo '{}' > config.json && echo '{}' > analytics.json && docker compose up -d --build`
  → ports 8789 (Test Prep) and 8790 (adventure). Create those two files first, or Docker makes empty
  folders with those names.
- **Easier starting:** a small start script or shortcut for their system is fine (`start-server.sh`
  and `start-server.cmd` are git-ignored names for exactly this).

**Don't run `docker-build-testprep.sh` or the `docker-compose-*-testprep.yml`/`-lightsail.yml` files**
unless the person is the maintainer and asks — they deploy to the maintainer's own Raspberry Pi and
cloud server.

---

## 2. Question packs

Packs are JSON files in `packs/`; the server lists them at startup (restart after adding one). Both
apps use the same packs, picked by grade (åk) first, then subject.

```json
{
  "title": "Biologi åk 4: Djur, växter, kroppen och naturen (Lgr22)",
  "grades": [4],
  "subject": "Biologi",
  "items": [
    {
      "front": "Vilken djurgrupp hör grodan till?",
      "back": "groddjur – de börjar livet i vattnet och lever sedan även på land.",
      "choices": ["groddjur", "kräldjur", "fiskar", "insekter"],
      "answerIndex": 0,
      "hint": "Den börjar som grodyngel i vattnet.",
      "tags": ["djur", "åk4"]
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `grades` | Grades the pack is for (`[4]`, `[7, 8, 9]`) — shown under each. Or instead: |
| `category` | `"fun"` for quizzes that aren't schoolwork (shown as "Kul & spel") |
| `subject` | Subject heading in Swedish: Matematik, Svenska, Engelska, Biologi, Fysik, Kemi, Teknik, Geografi, Historia, Religionskunskap, Samhällskunskap, Musik, Bild, Slöjd, Idrott och hälsa, Hem- och konsumentkunskap |
| `front` / `back` | Question / answer with a short explanation (shown after a wrong answer) |
| `choices` / `answerIndex` | Four choices, index of the right one |
| `hint` | Optional |
| `write` | `true` on items a child can answer in their own words ("Varför…", "Hur…", "Vad är…") — not numbers, single words, fill-in-the-blank or anything that depends on the choices. The adventure's final question is drawn from these |

**When writing packs** (a common request: "make packs for my child's grade"):
- Follow **Lgr22**: the subject's *centralt innehåll* for the stage (åk 1–3, 4–6, 7–9), at the level
  of the named grade. Ask what the class is working on if they know — textbooks and teachers differ.
- Swedish for every subject except English (and other language subjects). For English in åk 4–6,
  instructions and explanations in Swedish, the English in what's being practised.
- Exactly one right answer among four distinct choices; wrong choices are believable mistakes, not
  nonsense. Every question unique (flashcards and match show the question alone).
- Facts must be right — leave a question out rather than guess. Tell the person to read through the
  pack, since it will be used by a child.
- Name files `<subject>_ak<grade>.json` (e.g. `historia_ak5.json`); a topic pack
  `<subject>_ak<grade>_<topic>.json` (e.g. `historia_ak4_vikingatiden.json`).
- **A topic pack includes every question on that topic from the general pack** for the same subject
  and grade (copy them in), plus its own. The overlap with the general pack is intended. Drop your
  own question where it asks the same thing as a copied one, so the pack has no duplicates.
- Check before saying it's done:
  ```bash
  python3 -c "import json,sys; d=json.load(open(sys.argv[1])); it=d['items']; \
    assert all(len(i['choices'])==4 and len(set(i['choices']))==4 and 0<=i['answerIndex']<4 for i in it); \
    assert len({i['front'] for i in it})==len(it); print(d['title'], len(it), 'questions OK')" packs/historia_ak5.json
  curl -s http://localhost:8787/api/packs | grep -o '"historia_ak5.json"'   # after restarting the server
  ```

---

## 3. How the code is organised

| File | What |
|---|---|
| `server.js` | Zero-dependency `http` server. Serves `index.html`/`admin.html` on `PORT` and `adventure/` on `ADVENTURE_PORT`, plus the API. Reads `config.json` for `ANTHROPIC_API_KEY`, `WEATHER_LAT`, `WEATHER_LON` (environment variables win) |
| `index.html` | Test Prep — one file, vanilla JS |
| `adventure/index.html` | Kunskapsäventyret — one file, vanilla JS, all graphics inline SVG |
| `admin.html` | Usage dashboard (reads `analytics.json`, which the server writes; git-ignored). Behind a gateway (`X-Forwarded-User` set) it and `/api/analytics`/`/api/usage` are admin-only, and only the admin may choose the review model |
| `packs/*.json` | Question packs |
| `ROADMAP.md` | Ideas not built yet |

**API:** `GET /api/packs`, `GET /api/pack/<file>`, `POST /api/review` (Claude, Messages API, Haiku),
`POST /api/track` (analytics), `GET /api/analytics`, `GET /api/usage` (Claude reviews + estimated cost
per account, `CLAUDE_PRICES` in `server.js` — add a model there when switching), `GET /api/config` (`{hasClaude}`),
`GET /api/theme` (season, time of day, weather, holiday).

**Kunskapsäventyret** (`adventure/index.html`), from top to bottom:
- `CHARACTERS` (hiders and bosses) and `HEROES` — each `draw(mood)` returns SVG in a 100×100 box;
  moods `idle` / `happy` / `sad`. Helpers `eyes`, `mouth`, `cheeks`, `shadow`.
- `HOLIDAYS` — Halloween and Christmas change hiders, hiding places, place names, boss and final place.
  A game keeps the holiday it started with.
- `PLACES`, `ROUTES` — the places a journey visits; `SPOT_KINDS` — hiding places (how the animal peeks,
  clipping, where eyes can glint); `STYLE_WEIGHTS` — how hard hiding gets per place.
- Themes: `THEME_PRESETS`, `theme()`, `background()`, `shadeSvg()`, `startWeather()` (rain/snow
  canvas). `placeFree()` keeps big decorations off hiding places.
- Scoring: `BASE_POINTS`, `streakMultiplier`, `speedBonus`; the written final question:
  `WRITE_PASS_SCORE` (0–3 scale), `REVIEW_SYSTEM`.
- The UI is in Swedish; keep it that way.

**Conventions:**
- Keep it dependency-free (no npm packages, no build step, no CDN) unless there's a strong reason.
- Characters must be **original** — no trademarked or copyrighted characters (no Grinch, Rudolph,
  Disney…); public-domain figures like Dracula are fine. The repo is public (MIT).
- Never commit `config.json`, `.env` or `analytics.json`; never put a real key or someone's exact
  location in tracked files.

**Checking a change:**
```bash
node --check server.js
node -e "const s=require('fs').readFileSync('adventure/index.html','utf8'); new Function(s.split('<script>')[2].split('</script>')[0]); console.log('adventure script parses')"
```
Then run the server and look at it in a browser (or a headless browser if you have one) — the game is
visual, so check what changed actually looks right, on a phone-sized window too.
