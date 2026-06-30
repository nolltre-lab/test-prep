# Test Prep - Gamified Study Trainer

A gamified, self-hosted study application designed for students (grades 7-9) with multiple interactive learning modes. Features flashcards, quizzes, matching games, and AI-powered review with feedback.

## Features

- **Multiple Study Modes**
  - 📚 **Flashcards**: Traditional flip-card study with spaced repetition
  - ⚡ **Quick Quiz**: Timed multiple-choice questions with streak tracking
  - 🎯 **Match Terms**: Memory-style matching game
  - ✍️ **Write & Review**: Free-form answers with AI-powered feedback (requires OpenAI API key)

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

## Prerequisites

### For Local Development
- **Node.js** >= 18 (includes built-in `fetch`)
- **Optional**: OpenAI API key (only needed for Write & Review mode)

### For Docker Deployment
- **Docker** and **Docker Compose**
- **Optional**: OpenAI API key

### For Raspberry Pi Deployment
- **Raspberry Pi** (tested on Pi 4) running Raspberry Pi OS
- **Docker** installed on the Pi
- **macOS/Linux** deployment machine (for the build script)
- SSH access to the Pi
- **Optional**: OpenAI API key

## Getting Started

### Local Development (Standalone)

1. **Clone the repository**
   ```bash
   git clone https://github.com/nolltre-lab/test-prep.git
   cd test-prep
   ```

2. **Set up environment variables** (optional, for AI features)
   ```bash
   # Add to ~/.zshrc or ~/.bash_profile
   export OPENAI_API_KEY=sk-your-actual-api-key-here

   # Reload shell
   source ~/.zshrc
   ```

3. **Start the server**
   ```bash
   node server.js
   ```

4. **Open in browser**
   ```
   http://localhost:8787
   ```

The app will run without an OpenAI API key - the "Write & Review" mode will be automatically disabled if no key is configured.

### Docker (Local Testing)

1. **Build and run with Docker Compose**
   ```bash
   docker compose up -d
   ```

2. **Access the application**
   ```
   http://localhost:8789
   ```

3. **To use AI features**, create a `.env` file:
   ```bash
   cp .env.example .env
   # Edit .env and add your OpenAI API key
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
   export OPENAI_API_KEY="sk-your-actual-api-key-here"
   ```

4. **Run the deployment script**
   ```bash
   chmod +x docker-build-testprep.sh
   ./docker-build-testprep.sh
   ```

The script will (in **direct copy** mode - fast!):
- Build a Docker image for ARM64 (Raspberry Pi)
- Save the image as a tar file
- Copy it directly to the Pi over local network (fast!)
- Create a `.env` file on the Pi with your OpenAI API key
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
REMOTE_USER="${REMOTE_USER:-pi}"
REMOTE_HOST="${REMOTE_HOST:-raspberrypi.local}"
KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-raspberrypi_scp}"
```

## OpenAI API Key Setup

The "Write & Review" mode uses OpenAI's API to provide intelligent feedback on student answers.

### Getting an API Key

1. **Sign up** at [OpenAI Platform](https://platform.openai.com/)
2. **Create an API key** at [API Keys](https://platform.openai.com/api-keys)
3. **Copy** the key (starts with `sk-`)

### Setting the API Key

#### Local Development
```bash
# Add to your shell profile (~/.zshrc or ~/.bash_profile)
export OPENAI_API_KEY=sk-your-actual-api-key-here
source ~/.zshrc
```

#### Docker Local
```bash
# Create .env file
echo "OPENAI_API_KEY=sk-your-actual-api-key-here" > .env

# Restart container
docker compose down && docker compose up -d
```

#### Raspberry Pi
```bash
# Set before running the deployment script
export OPENAI_API_KEY=sk-your-actual-api-key-here
./docker-build-testprep.sh
```

The script will automatically create and upload the `.env` file to your Pi.

### Running Without an API Key

The application works perfectly fine without an OpenAI API key! The "Write & Review" button will be automatically disabled and show a tooltip explaining why. All other modes (Flashcards, Quiz, Match) work without any API key.

## Creating Question Packs

Question packs are JSON files stored in the `packs/` directory.

### Basic Structure

```json
{
  "title": "Physics: Electricity Basics",
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
| `items` | Yes | Array of questions |
| `front` | Yes | The question text |
| `back` | Yes | The answer/explanation |
| `hint` | No | Optional hint (shown in quiz mode when pressing 'H') |
| `tags` | No | Array of tags for categorization |
| `choices` | No | Array of multiple-choice options (for quiz mode) |
| `answerIndex` | No | Index of correct answer in `choices` array (0-based) |

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
| `OPENAI_API_KEY` | OpenAI API key for AI review | None (optional) |
| `PORT` | Server port | 8787 |

### config.json

Non-sensitive configuration settings:

```json
{
  "model": "gpt-4o-mini",
  "host": "127.0.0.1",
  "port": 8787,
  "packs_dir": "./packs",
  "public_dir": "./public",
  "max_body_bytes": 200000,
  "rate_limit_per_min": 30
}
```

**Note**: The API key should NOT be in `config.json` - use environment variables instead.

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

- **Local Development**: `http://localhost:8787/admin.html`
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
- **Verify API key** is set: `echo $OPENAI_API_KEY`
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
- **AI Integration**: OpenAI GPT-4o-mini (via REST API)

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/config` | GET | Check server capabilities (OpenAI status) |
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
