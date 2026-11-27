# Test Prep - Gamified Study Trainer

A gamified, self-hosted study application for school students (Swedish curriculum, Lgr22 — packs for åk 3, 4 and 7–9) with flashcards, quizzes, matching games and AI-powered review with feedback, plus **Kunskapsäventyret**, an adventure game for younger players built on the same question packs.

## Run it on your own computer

> **Using Claude Code?** Open this folder and ask it to *"set this up for me"* — [CLAUDE.md](CLAUDE.md)
> tells it how (Node.js, starting the server, an optional Claude key, your town's weather, packs for
> your child's grade).

Everything runs on a laptop with **no cloud server, no database and nothing to install** apart from
Node.js. Test Prep and Kunskapsäventyret both start from the same small server, and every question
pack is included.

**1. Install Node.js 18 or newer** — the "LTS" download from [nodejs.org](https://nodejs.org/)
(Windows, macOS and Linux). Check with `node --version`.

**2. Get the code** — either clone it:
```bash
git clone https://github.com/nolltre-lab/test-prep.git
cd test-prep
```
or click **Code → Download ZIP** on GitHub, unzip it and open a terminal in that folder.

**3. Start it** (there is no `npm install` — the server has no dependencies):
```bash
node server.js
```

**4. Open it in a browser:**

| What | Address |
|---|---|
| Test Prep (flashcards, quiz, match, write & review) | http://localhost:8787 |
| Kunskapsäventyret (the adventure game) | http://localhost:8788 |
| Usage dashboard | http://localhost:8787/admin.html |

Stop the server with `Ctrl+C`. Progress is saved in each browser.

Everything works straight away **except Write & Review** in Test Prep and the dragon's written
question in the adventure — those need a Claude API key (step 5). Without one, Write & Review is
switched off and the dragon asks an ordinary question instead.

### 5. Optional: add a Claude API key for Write & Review

1. Create a key at [console.anthropic.com](https://console.anthropic.com/settings/keys) (it starts
   with `sk-ant-`). The API is paid per use: you need to add credit to the account. Reviews use the
   small, cheap Haiku model — a review costs a fraction of a cent.
2. Give the key to the server in **one** of these ways, then start it again:

   **Easiest, any system — a `config.json` file** in the project folder (next to `server.js`):
   ```json
   { "ANTHROPIC_API_KEY": "sk-ant-your-key-here" }
   ```

   **Or an environment variable** when you start the server:
   ```bash
   # macOS / Linux
   ANTHROPIC_API_KEY=sk-ant-your-key-here node server.js
   ```
   ```powershell
   # Windows PowerShell
   $env:ANTHROPIC_API_KEY="sk-ant-your-key-here"; node server.js
   ```
   ```bat
   :: Windows Command Prompt
   set "ANTHROPIC_API_KEY=sk-ant-your-key-here" && node server.js
   ```
3. The warning `No ANTHROPIC_API_KEY set` should no longer appear when the server starts, and the
   **Write & Review** button is enabled.

Keep the key private: `config.json` and `.env` are git-ignored, so they are never committed — don't
paste the key anywhere else in the code.

### More options

- **Weather for the adventure's themes:** the scenery follows the season, weather and time of day
  for one place (default central Stockholm; weather from [Open-Meteo](https://open-meteo.com/), free,
  no key). For your own town, add it to `config.json` — two decimals is plenty:
  ```json
  { "WEATHER_LAT": 57.71, "WEATHER_LON": 11.97 }
  ```
  Without internet, the theme still follows the season and time of day from the clock.
- **Other ports:** `PORT=9000 node server.js` (Test Prep on 9000; the adventure goes on `PORT + 1`, or
  set `ADVENTURE_PORT`).
- **On a phone or tablet:** with the server running on a laptop, other devices on the same Wi-Fi can
  open `http://<the laptop's IP address>:8787` and `:8788`. There is no login — anyone on that
  network can use it.
- **With Docker instead of Node:** create the two files Docker mounts, then start it:
  ```bash
  echo '{}' > config.json && echo '{}' > analytics.json
  docker compose up -d --build
  ```
  Test Prep is then on http://localhost:8789 and the adventure on http://localhost:8790. For a Claude
  key, put `ANTHROPIC_API_KEY=sk-ant-…` in a `.env` file (copy `.env.example`) or in `config.json`,
  and run `docker compose up -d` again.
- **Your own question packs:** drop a JSON file in `packs/` and restart — see
  [Creating Question Packs](#creating-question-packs).

The deployment sections further down (Raspberry Pi, Lightsail) are only for running it on a server
for others; you don't need them to use it yourself.

## Features

- **Multiple Study Modes**
  - 📚 **Flashcards**: Traditional flip-card study with spaced repetition
  - ⚡ **Quick Quiz**: Timed multiple-choice questions with streak tracking
  - 🎯 **Match Terms**: Memory-style matching game
  - ✍️ **Write & Review**: Free-form answers with AI-powered feedback (requires Anthropic/Claude API key)

- **Progress Tracking**
  - XP and leveling system
  - Streak tracking and personal bests
  - Per-pack progress persistence
  - Visual progress bars

- **Content Management**
  - Pre-loaded question packs (Swedish curriculum subjects)
  - Import custom JSON question packs
  - Load from local folders
  - Server-managed pack library

- **AI-Powered Review** (Optional)
  - Context-aware feedback
  - Detailed scoring on correctness, clarity, completeness, and technical accuracy
  - Suggested improvements
  - Adapts to question type (conceptual vs. calculation-based)

- **Responsive Design**
  - Mobile-friendly interface
  - Touch-optimized controls
  - Keyboard shortcuts for desktop

- **Analytics & Management Dashboard**
  - Real-time usage analytics
  - Client activity tracking (by IP/hostname)
  - Pack popularity statistics
  - Review score analytics with averages
  - Session tracking with timestamps
  - Auto-refresh dashboard (30s interval)

## Kunskapsäventyret (adventure game)

A second app in the same server, for younger players (around 10 years old). Pick one of twelve
heroes (a panda, a corgi, a dinosaur in a party hat, a banana with a moustache…) and a pack, then
explore a series of places — a forest glade, a lake, a valley with a waterfall, a mushroom forest,
a mountain. In each place animals hide behind bushes, logs, rocks and leaf piles, in reeds, in tree
hollows and under water, peeking out now and then. Tap to walk there; a found animal asks a question
from the pack (3 stars on the first try, fewer after a miss, with a new question each time). When
every animal in a place has been answered, a bridge appears over the stream (or a boulder rolls
away) and the signpost leads on. A friendly dragon at the castle asks three in a row. 🔍 makes one
hidden animal peek out (costs 10 points). Progress is saved in the browser.

Animals hide in different ways — peeking now and then, only glinting eyes, leaving clues (tracks,
feathers, rustling, bubbles), or running off when found — and later places get harder.

**Scoring** (same rules as Test Prep Quiz): 10 points per right answer, × 2 after 3 in a row and × 3
after 5 in a row, plus a speed bonus of +5/+3/+1 while the timer bar is still three-quarters/half/a
quarter full. Records are kept per pack and adventure length, so you compete with yourself.

**Themes:** by default the scenery follows the season, the weather and the time of day where the app
is set up (`GET /api/theme`, Open-Meteo weather for `WEATHER_LAT`/`WEATHER_LON` from the environment
or `config.json`, default central Stockholm; cached 15 minutes; season and time from the clock if the
weather can't be fetched), with Halloween and Christmas decorations around those dates. A theme can
also be picked on the start screen (Vår, Sommar, Höst, Vinter, Natt, Halloween, Jul). Plans: see
[ROADMAP.md](ROADMAP.md).

**The dragon's last question** is answered in writing when the pack has questions marked
`"write": true` and the server has a Claude key: it goes to `/api/review`, and an overall score of
at least `WRITE_PASS_SCORE` (2 of 3) passes. A miss gives feedback and up to three tries; without
Claude it's an ordinary question.

- Source: `adventure/index.html` (one file, no dependencies; all characters and scenery are inline SVG)
- Served on its own port: `ADVENTURE_PORT` (default `PORT + 1`, i.e. 8788), e.g.
  `http://127.0.0.1:8788/`. Also reachable on the main port at `/adventure/`.
- Uses the same `/api/packs`, `/api/pack/:file` and `/api/track` (type `adventure`) as Test Prep,
  so every pack works in both apps. Items without `choices` get wrong answers borrowed from other
  items' answers.

## Prerequisites

### For Local Development
- **Node.js** >= 18 (includes built-in `fetch`)
- **Optional**: Anthropic (Claude) API key (only needed for Write & Review mode)

### For Docker Deployment
- **Docker** and **Docker Compose**
- **Optional**: Anthropic (Claude) API key

### For Raspberry Pi Deployment
- **Raspberry Pi** (tested on Pi 4) running Raspberry Pi OS
- **Docker** installed on the Pi
- **macOS/Linux** deployment machine (for the build script)
- SSH access to the Pi
- **Optional**: Anthropic (Claude) API key

## Getting Started

### Local Development (Standalone)

See [Run it on your own computer](#run-it-on-your-own-computer) at the top: `node server.js`, then
http://localhost:8787 (Test Prep) and http://localhost:8788 (Kunskapsäventyret).

### Docker (Local Testing)

1. **Create the files Docker mounts, then build and run with Docker Compose** (without them Docker
   creates empty folders with those names)
   ```bash
   echo '{}' > config.json && echo '{}' > analytics.json
   docker compose up -d --build
   ```

2. **Access the application**
   ```
   http://localhost:8789   (Test Prep)
   http://localhost:8790   (Kunskapsäventyret)
   ```

3. **To use AI features**, create a `.env` file:
   ```bash
   cp .env.example .env
   # Edit .env and add your Anthropic API key
   ```

4. **Restart the container**
   ```bash
   docker compose down
   docker compose up -d
   ```

### Raspberry Pi Deployment

This project includes a fully automated deployment script for Raspberry Pi.

#### Prerequisites
- Raspberry Pi accessible via SSH (`raspberrypi.local` or custom hostname)
- Docker installed on the Pi
- macOS with Keychain for password management
- Tools: `docker`, `security`, `sshpass`, `ssh`, `scp`

#### Setup Steps

1. **Install dependencies** (macOS)
   ```bash
   brew install sshpass
   ```

2. **Store SSH password in Keychain**
   ```bash
   security add-generic-password -s raspberrypi_scp -a magnusjohansson -w
   # Enter your Pi's SSH password when prompted
   ```

3. **Configure environment variables**

   Edit the script or set environment variables:
   ```bash
   export DOCKER_REPO="iqesolutions/test-prep"
   export REMOTE_USER="your-pi-username"
   export REMOTE_HOST="raspberrypi.local"
   ```

   The Claude API key doesn't need an env var at all if it's already in Keychain (see
   [Claude API Key Setup](#claude-anthropic-api-key-setup) below) — the script fetches it
   automatically. Set `ANTHROPIC_API_KEY` only if you want to override that.

4. **Run the deployment script**
   ```bash
   chmod +x docker-build-testprep.sh
   ./docker-build-testprep.sh
   ```

The script will (in **direct copy** mode - fast!):
- Build a Docker image for ARM64 (Raspberry Pi)
- Save the image as a tar file
- Copy it directly to the Pi over local network (fast!)
- Create a `.env` file on the Pi with your Claude API key (from Keychain, or the env var override)
- Upload configuration files
- Load the image and start the container
- Perform a health check

**Fast deployment**: Typically completes in 30-90 seconds!

Optional: Push to Docker Hub as backup:
```bash
PUSH_TO_HUB=1 ./docker-build-testprep.sh
```

5. **Access your app**
   ```
   http://raspberrypi.local:8789
   ```

#### Customizing the Deployment

Edit variables at the top of `docker-build-testprep.sh`:

```bash
DOCKER_REPO="${DOCKER_REPO:-iqesolutions/test-prep}"
TAG="${TAG:-latest}"
REMOTE_USER="${REMOTE_USER:-magnusjohansson}"
REMOTE_HOST="${REMOTE_HOST:-raspberrypi.local}"
PI_KEYCHAIN_SERVICE="${PI_KEYCHAIN_SERVICE:-raspberrypi_scp}"
ANTHROPIC_KEYCHAIN_SERVICE="${ANTHROPIC_KEYCHAIN_SERVICE:-testprep_anthropic_api_key}"
```

### Lightsail Deployment

The same script also deploys to an AWS Lightsail instance (key-based SSH, behind the `apps-home`
Caddy reverse proxy and its sign-in, on this app's own `edge-test-prep` Docker network) — used for
the maintainer's internet-facing deployment rather than a local-network Raspberry Pi.

```bash
TARGET=lightsail ./docker-build-testprep.sh
```

Requires:
- `LIGHTSAIL_IP` env var, **or** a Keychain entry named `lightsail_ip`:
  ```bash
  security add-generic-password -s lightsail_ip -a lightsail -w <your-lightsail-ip>
  ```
- An SSH key at `~/.ssh/lightsail.pem` (override with `LIGHTSAIL_KEY`)

The Claude API key is picked up the same way as for the Pi target — see
[Claude (Anthropic) API Key Setup](#claude-anthropic-api-key-setup) below.

## Claude (Anthropic) API Key Setup

The "Write & Review" mode uses Anthropic's Claude API (Messages API, model `claude-haiku-4-5-20251001`
by default) to provide intelligent feedback on student answers.

### Getting an API Key

1. **Sign up** at [Anthropic Console](https://console.anthropic.com/)
2. **Create an API key** at [API Keys](https://console.anthropic.com/settings/keys)
3. **Copy** the key (starts with `sk-ant-`)

### Setting the API Key

#### Local Development
Put it in `config.json` next to `server.js` (git-ignored), or set the environment variable — see
[step 5 of Run it on your own computer](#5-optional-add-a-claude-api-key-for-write--review) for
macOS, Linux and Windows. To keep it set in every terminal on macOS/Linux:
```bash
# Add to your shell profile (~/.zshrc or ~/.bash_profile)
export ANTHROPIC_API_KEY=sk-ant-your-actual-api-key-here
source ~/.zshrc
```

#### Docker Local
```bash
# Create .env file
echo "ANTHROPIC_API_KEY=sk-ant-your-actual-api-key-here" > .env

# Restart container
docker compose down && docker compose up -d
```

#### Raspberry Pi / Lightsail deployment script (recommended: Keychain)
Store the key once in macOS Keychain and the deploy script picks it up automatically for either
target — no env var needed on every run:
```bash
security add-generic-password -s testprep_anthropic_api_key -a "$USER" -w sk-ant-your-actual-api-key-here
./docker-build-testprep.sh                       # Pi
TARGET=lightsail ./docker-build-testprep.sh      # Lightsail
```
To override without touching Keychain (e.g. rotating a key temporarily), set the env var instead —
it takes precedence over Keychain:
```bash
export ANTHROPIC_API_KEY=sk-ant-your-actual-api-key-here
./docker-build-testprep.sh
```

Either way, the script creates and uploads the `.env` file to the remote host automatically.

### Running Without an API Key

The application works perfectly fine without a Claude API key! The "Write & Review" button will be automatically disabled and show a tooltip explaining why. All other modes (Flashcards, Quiz, Match) work without any API key.

## Creating Question Packs

Question packs are JSON files stored in the `packs/` directory.

### Basic Structure

```json
{
  "title": "Fysik åk 7: Elektricitet",
  "grades": [7],
  "subject": "Fysik",
  "items": [
    {
      "front": "What is electric current?",
      "back": "The flow of electric charge through a conductor, measured in amperes (A).",
      "hint": "Think about movement of charges",
      "tags": ["physics", "electricity", "basic"],
      "choices": [
        "The flow of electric charge",
        "Stored electrical energy",
        "Resistance in a wire",
        "Voltage difference"
      ],
      "answerIndex": 0
    }
  ]
}
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Pack name shown in the UI |
| `grades` | One of these two | Grades (åk) the pack is for, e.g. `[4]` or `[7, 8, 9]` — the pickers show it under each |
| `category` | One of these two | For packs that aren't schoolwork: `"fun"` (shown as "Kul & spel"). Packs with neither land under "Övrigt" |
| `subject` | Yes | Subject heading the pack is grouped under, in Swedish (`Matematik`, `Engelska`, `Film`…) |
| `write` | No | On an item: `true` if it can be answered in your own words (explain, describe, why…) — not for a number, a single word or anything that depends on the choices. The adventure's dragon asks one of these in writing |
| `items` | Yes | Array of questions |
| `front` | Yes | The question text |
| `back` | Yes | The answer/explanation |
| `hint` | No | Optional hint (shown in quiz mode when pressing 'H') |
| `tags` | No | Array of tags for categorization |
| `choices` | No | Array of multiple-choice options (for quiz mode) |
| `answerIndex` | No | Index of correct answer in `choices` array (0-based) |

### Content guidelines

- **Every pack says where it belongs:** `grades` (or `category` for quizzes that aren't
  schoolwork) and `subject`. Both apps pick packs by grade first, then by subject.
- **Follow the Swedish curriculum (Lgr22)** for the subject and grade: build on the subject's
  *centralt innehåll* for that stage (åk 1–3, 4–6, 7–9) at the level of the named grade, and use
  Swedish terms where Swedish schools do. Put the grade in the title and file name
  (`Engelska åk 4: …`, `english_ak4.json`) and tag items with it (`"åk4"`).
- **Language:** Swedish for every subject except English (and other language subjects). For English
  in the younger years (åk 4–6), give instructions and explanations in Swedish and keep the English
  in the words and sentences being practised, so a child can manage alone.
- **Mark open questions with `"write": true`** — the ones a child can answer in their own words
  ("Varför…", "Vad är…", "Hur…"), so the adventure's written final question has something to ask.
- **Every item has four choices** with exactly one right answer, and a `back` that explains why —
  the quiz modes and the adventure show it after a wrong answer. Add a `hint` where it helps.
- Wrong choices should be believable mistakes (half past one for "halv ett", mouses for mice), not
  nonsense.
- **Topic packs include the general pack's questions on that topic.** A pack on one theme
  (`historia_ak4_vikingatiden.json`) copies every question on that theme from the subject's general
  pack for the grade (`historia_ak4.json`) as well as its own, so it covers the topic on its own.
  The overlap between the two packs is intended. Within one pack, every question is still unique.

### Adding Packs

1. **Create** a JSON file in the `packs/` directory
2. **Restart** the server (or rebuild Docker image)
3. **Select** the pack from the dropdown menu in the app

### Examples

The repository includes several example packs:
- `packs/physics_*.json` - Physics topics (Swedish)
- `packs/matematik_*.json` - Mathematics
- `packs/english_*.json` - English vocabulary
- And many more...

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | Anthropic (Claude) API key for Write & Review | None (optional) |
| `PORT` | Test Prep's port | 8787 |
| `ADVENTURE_PORT` | Kunskapsäventyret's port | `PORT + 1` (8788) |
| `WEATHER_LAT`, `WEATHER_LON` | Place whose weather the adventure's themes follow | 59.33, 18.07 (Stockholm) |

### config.json

Optional, git-ignored file next to `server.js`. The server reads these keys from it (an
environment variable with the same name wins):

```json
{
  "ANTHROPIC_API_KEY": "sk-ant-your-key-here",
  "WEATHER_LAT": 59.33,
  "WEATHER_LON": 18.07
}
```

On your own computer `config.json` is the simplest place for the key. On a shared server, prefer an
environment variable or a `.env` file that only the server can read.

## Usage

### Keyboard Shortcuts

**Flashcard Mode**
- `Space` - Flip card
- `→` - Next card
- `←` - Previous card

**Quiz Mode**
- `H` - Show/hide hint

### Study Tips

1. **Start with Flashcards** to familiarize yourself with content
2. **Use Quick Quiz** to test your recall under time pressure
3. **Try Match Terms** for a fun way to reinforce connections
4. **Practice Write & Review** for deeper understanding and detailed feedback

### Progress Tracking

- Progress is saved **per pack** in browser localStorage
- **XP** accumulates across all activities
- **Streaks** reset on wrong answers
- **Level** increases based on total XP

## Management Dashboard

The application includes a real-time analytics dashboard for teachers and administrators to monitor student usage and progress.

### Accessing the Dashboard

Navigate to the `/admin.html` page:

- **Local Development**: `http://localhost:8787/admin.html` (adventure answers are included as type `adventure`)
- **Docker**: `http://localhost:8789/admin.html`
- **Raspberry Pi**: `http://raspberrypi.local:8789/admin.html`

### Dashboard Features

**Summary Statistics**
- Total active clients (unique IP addresses)
- Total reviews submitted
- Number of unique packs used
- Average overall review score

**Active Clients Table**
- Client IP addresses and hostnames
- Number of packs each client has used
- Review count per client
- Last activity timestamp with relative time display

**Pack Usage Statistics**
- Most popular question packs ranked by usage count
- Total loads per pack
- Helps identify which topics are most studied

**Average Review Scores**
- Visual score bars for all assessment metrics:
  - Correctness (accuracy of answers)
  - Clarity (communication quality)
  - Completeness (thoroughness)
  - Technical Accuracy (units, calculations, etc.)
  - Overall Score (combined assessment)
- Based on last 100 review submissions

**Recent Reviews**
- Timestamped submission log
- Client identification
- Question previews
- Score badges (color-coded)
- Word count statistics

### Dashboard Behavior

- **Auto-refresh**: Updates every 30 seconds automatically
- **Manual Refresh**: Click the refresh button for immediate update
- **Data Persistence**: Analytics are saved to `analytics.json` on the server
- **Historical Data**: Keeps last 1000 reviews in storage
- **Privacy**: Only tracks IP addresses and hostnames (local network identification)

### Analytics Data Storage

All analytics data is stored in `analytics.json` in the application root directory:
- Debounced writes (saves maximum once per minute to reduce disk I/O)
- Survives server restarts
- Can be backed up or analyzed externally
- JSON format for easy parsing

**Note**: The dashboard is accessible to anyone who can reach the server. For production use in a classroom environment on an internal network, this is typically acceptable. For internet-facing deployments, consider adding authentication.

## Troubleshooting

### Server won't start
- **Check Node version**: `node --version` (must be >= 18)
- **Check port availability**: `lsof -i :8787`
- **Review logs** for errors

### Write & Review mode disabled
- **Verify API key** is set: `echo $ANTHROPIC_API_KEY`
- **Check server logs** for API key warnings
- **Restart server** after setting environment variable

### Docker build fails
- **Check Docker version**: `docker --version`
- **Ensure buildx** is available: `docker buildx version`
- **Verify Docker Hub** authentication: `docker login`

### Raspberry Pi deployment fails
- **Test SSH connection**: `ssh user@raspberrypi.local`
- **Verify Keychain password**: `security find-generic-password -s raspberrypi_scp -w`
- **Check Pi has Docker**: SSH to Pi and run `docker --version`
- **Review script output** for specific error messages

### Claude API key not picked up during deploy
- **Verify it's in Keychain**: `security find-generic-password -s testprep_anthropic_api_key -w`
- **Check for an env var shadowing it**: `echo $ANTHROPIC_API_KEY` — a stale/wrong value here takes precedence over Keychain
- **Look for the deploy log line**: should say either "Using ANTHROPIC_API_KEY from environment" or "Claude API key from Keychain" — if neither appears, no key was found on either path

### Question packs not showing
- **Verify JSON syntax**: Use a JSON validator
- **Check file location**: Must be in `packs/` directory
- **Restart server** after adding new packs
- **Check permissions**: Files must be readable

## Project Structure

```
.
├── index.html                              # Main application (SPA)
├── admin.html                              # Management dashboard (analytics)
├── server.js                               # Node.js backend server
├── analytics.json                          # Analytics data storage (auto-generated)
├── Dockerfile                              # Docker image definition
├── docker-compose.yml                      # Local Docker setup
├── docker-compose-headless-testprep.yml   # Pi deployment config
├── docker-build-testprep.sh               # Automated Pi deployment script
├── config.json                            # Non-sensitive configuration
├── .env.example                           # Environment variable template
├── packs/                                 # Question pack library
│   ├── physics_*.json
│   ├── matematik_*.json
│   └── ...
└── README.md                              # This file
```

## Technical Details

### Stack
- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **Backend**: Node.js (zero dependencies except built-in modules)
- **Containerization**: Docker, multi-arch builds (amd64/arm64)
- **AI Integration**: Anthropic Claude, `claude-haiku-4-5-20251001` by default (via REST API)

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/config` | GET | Check server capabilities (Claude API status) |
| `/api/packs` | GET | List available question packs |
| `/api/pack/:filename` | GET | Fetch specific pack contents |
| `/api/review` | POST | Submit answer for AI review |
| `/api/analytics` | GET | Get analytics data (sessions, pack usage, review stats) |

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Workflow

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally with `node server.js`
5. Submit a pull request

## License

MIT License - feel free to use this for educational purposes!

## Acknowledgments

- Built for Swedish middle school students (åk 7-9)
- Designed to work offline (except AI review)
- Optimized for Raspberry Pi deployment in classrooms

## Support

For issues, questions, or suggestions:
- **GitHub Issues**: [Create an issue](https://github.com/nolltre-lab/test-prep/issues)
- **Documentation**: See this README

---

**Happy studying! 📚🚀**
