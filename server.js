// server.js — zero-dependency Node server for Test Prep
// Node >= 18 required (built-in fetch).
// Reads Anthropic key from ENV ANTHROPIC_API_KEY or ./config.json { "ANTHROPIC_API_KEY": "sk-ant-..." }

const http = require("http");
const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");
const { URL } = require("url");

const ROOT = __dirname;
const PUBLIC_DIR = ROOT;            // serve index.html and static files from here
const PACKS_DIR = path.join(ROOT, "packs");
const PORT = process.env.PORT ? Number(process.env.PORT) : 8787;
const ANALYTICS_FILE = path.join(ROOT, "analytics.json");

// --- Load config / API key ---
let ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || "";
const cfgPath = path.join(ROOT, "config.json");
if (!ANTHROPIC_API_KEY && fs.existsSync(cfgPath)) {
  try {
    const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf-8"));
    if (cfg.ANTHROPIC_API_KEY) ANTHROPIC_API_KEY = cfg.ANTHROPIC_API_KEY;
    if (cfg.PORT && !process.env.PORT) console.warn("Tip: You can set PORT in config.json, but ENV wins.");
  } catch (e) {
    console.warn("Could not read config.json:", e.message);
  }
}
if (!ANTHROPIC_API_KEY) {
  console.warn("\n⚠️  No ANTHROPIC_API_KEY set. /api/review will return 503 until you add one.\n" +
               "   Set env var ANTHROPIC_API_KEY or create config.json with { \"ANTHROPIC_API_KEY\": \"sk-ant-...\" }\n");
}

// --- Analytics System ---
const analytics = {
  sessions: new Map(),      // clientId -> session data
  reviews: [],              // all review submissions
  packUsage: new Map(),     // packId -> usage count
  packSessions: [],         // detailed pack activity sessions
  quizActivity: [],         // quiz question attempts
  packPerformance: new Map(), // clientId -> packId -> performance stats
  lastSave: Date.now()
};

// Load analytics from file
try {
  if (fs.existsSync(ANALYTICS_FILE)) {
    const data = JSON.parse(fs.readFileSync(ANALYTICS_FILE, "utf-8"));
    if (data.sessions) {
      analytics.sessions = new Map(Object.entries(data.sessions));
      analytics.sessions.forEach(session => {
        session.packsUsed = new Set(Array.isArray(session.packsUsed) ? session.packsUsed : []);
      });
    }
    if (data.reviews) analytics.reviews = data.reviews || [];
    if (data.packUsage) analytics.packUsage = new Map(Object.entries(data.packUsage));
    if (data.packSessions) analytics.packSessions = data.packSessions || [];
    if (data.quizActivity) analytics.quizActivity = data.quizActivity || [];
    if (data.packPerformance) {
      analytics.packPerformance = new Map();
      Object.entries(data.packPerformance).forEach(([clientId, packs]) => {
        analytics.packPerformance.set(clientId, new Map(Object.entries(packs)));
      });
    }
    console.log(`📊 Loaded analytics: ${analytics.sessions.size} sessions, ${analytics.reviews.length} reviews, ${analytics.quizActivity.length} quiz attempts`);
  }
} catch (e) {
  console.warn("Could not load analytics.json:", e.message);
}

// Save analytics to file (debounced)
function saveAnalytics() {
  const now = Date.now();
  if (now - analytics.lastSave < 60000) return; // Save max once per minute
  analytics.lastSave = now;

  // Convert nested Maps to objects for JSON serialization
  const packPerfObj = {};
  analytics.packPerformance.forEach((packs, clientId) => {
    packPerfObj[clientId] = Object.fromEntries(packs);
  });

  const sessionsObj = {};
  analytics.sessions.forEach((session, clientId) => {
    sessionsObj[clientId] = { ...session, packsUsed: Array.from(session.packsUsed) };
  });

  const data = {
    sessions: sessionsObj,
    reviews: analytics.reviews.slice(-1000), // Keep last 1000 reviews
    packUsage: Object.fromEntries(analytics.packUsage),
    packSessions: analytics.packSessions.slice(-2000), // Keep last 2000 sessions
    quizActivity: analytics.quizActivity.slice(-5000), // Keep last 5000 quiz attempts
    packPerformance: packPerfObj,
    savedAt: new Date().toISOString()
  };

  fs.writeFile(ANALYTICS_FILE, JSON.stringify(data, null, 2), err => {
    if (err) console.error("Failed to save analytics:", err.message);
  });
}

// Get or create session for client
function getClientSession(req) {
  const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
             req.socket.remoteAddress ||
             'unknown';
  const hostname = req.headers['x-forwarded-host'] || req.headers['host'] || 'unknown';
  const clientId = `${ip}`;

  if (!analytics.sessions.has(clientId)) {
    analytics.sessions.set(clientId, {
      clientId,
      ip,
      hostname,
      firstSeen: new Date().toISOString(),
      lastSeen: new Date().toISOString(),
      packsUsed: new Set(),
      reviewCount: 0,
      totalReviews: 0
    });
  }

  const session = analytics.sessions.get(clientId);
  session.lastSeen = new Date().toISOString();
  return session;
}

// Track pack usage
function trackPackUsage(packId, session) {
  if (!packId) return;

  session.packsUsed.add(packId);
  const count = analytics.packUsage.get(packId) || 0;
  analytics.packUsage.set(packId, count + 1);
}

// Track review submission
function trackReview(req, reviewData) {
  const session = getClientSession(req);
  session.reviewCount++;
  session.totalReviews++;

  analytics.reviews.push({
    timestamp: new Date().toISOString(),
    clientId: session.clientId,
    question: reviewData.user?.question || '',
    scores: {
      correctness: reviewData.review?.correctness_score,
      clarity: reviewData.review?.clarity_score,
      completeness: reviewData.review?.completeness_score,
      technical: reviewData.review?.technical_accuracy_score,
      overall: reviewData.review?.overall_score
    },
    wordCount: reviewData.user?.student_answer?.split(/\s+/).filter(Boolean).length || 0
  });

  saveAnalytics();
}

// Track pack activity session (start/end)
function trackPackSession(req, packId, action, duration = null) {
  const session = getClientSession(req);

  analytics.packSessions.push({
    timestamp: new Date().toISOString(),
    clientId: session.clientId,
    packId,
    action, // 'start' or 'end'
    duration // time spent in milliseconds (only for 'end')
  });

  saveAnalytics();
}

// Track quiz activity
function trackQuizActivity(req, packId, questionData) {
  const session = getClientSession(req);
  const { question, userAnswer, correctAnswer, isCorrect, mode, timeTaken } = questionData;

  analytics.quizActivity.push({
    timestamp: new Date().toISOString(),
    clientId: session.clientId,
    packId,
    question: question || '',
    userAnswer,
    correctAnswer,
    isCorrect,
    mode, // 'quiz', 'flashcard', 'match', etc.
    timeTaken // time to answer in milliseconds
  });

  // Update pack performance stats
  if (!analytics.packPerformance.has(session.clientId)) {
    analytics.packPerformance.set(session.clientId, new Map());
  }
  const clientPacks = analytics.packPerformance.get(session.clientId);

  if (!clientPacks.has(packId)) {
    clientPacks.set(packId, {
      totalAttempts: 0,
      correctAttempts: 0,
      totalTime: 0,
      lastActivity: new Date().toISOString()
    });
  }

  const packStats = clientPacks.get(packId);
  packStats.totalAttempts++;
  if (isCorrect) packStats.correctAttempts++;
  if (timeTaken) packStats.totalTime += timeTaken;
  packStats.lastActivity = new Date().toISOString();

  saveAnalytics();
}

// --- tiny helpers ---
function sendJSON(res, code, obj) {
  const data = JSON.stringify(obj);
  res.writeHead(code, {"Content-Type":"application/json","Cache-Control":"no-store"});
  res.end(data);
}
function sendText(res, code, text, contentType="text/plain; charset=utf-8") {
  res.writeHead(code, {"Content-Type": contentType});
  res.end(text);
}
function safeJoin(base, p) {
  const target = path.join(base, p);
  const rel = path.relative(base, target);
  if (rel.startsWith("..") || path.isAbsolute(rel)) return null;
  return target;
}
async function readBody(req) {
  const chunks=[]; for await (const c of req) chunks.push(c);
  const buf = Buffer.concat(chunks).toString("utf-8");
  try { return JSON.parse(buf || "{}"); } catch { return {}; }
}

// --- API: list packs ---
async function handleListPacks(res) {
  let names = [];
  try {
    const dir = await fsp.readdir(PACKS_DIR, { withFileTypes: true });
    names = dir.filter(d=>d.isFile() && d.name.toLowerCase().endsWith(".json")).map(d=>d.name);
  } catch {
    // no packs dir -> return empty
  }
  const out = [];
  for (const name of names) {
    try {
      const full = path.join(PACKS_DIR, name);
      const txt = await fsp.readFile(full, "utf-8");
      const obj = JSON.parse(txt);
      out.push({
        file: name,
        title: (obj && obj.title) ? obj.title : name,
        count: Array.isArray(obj?.items) ? obj.items.length : 0
      });
    } catch {
      // skip bad file
    }
  }
  return sendJSON(res, 200, { packs: out });
}

// --- API: fetch one pack ---
async function handleGetPack(req, res, fnameRaw) {
  const fname = path.basename(fnameRaw); // prevent traversal
  const full = safeJoin(PACKS_DIR, fname);
  if (!full || !full.toLowerCase().endsWith(".json")) {
    return sendJSON(res, 400, { error: "Bad file name" });
  }
  try {
    const txt = await fsp.readFile(full, "utf-8");
    const obj = JSON.parse(txt);

    // Track pack usage
    const session = getClientSession(req);
    trackPackUsage(fname, session);
    saveAnalytics();

    return sendJSON(res, 200, obj);
  } catch (e) {
    return sendJSON(res, 404, { error: "Pack not found or invalid JSON", detail: e.message });
  }
}

// --- API: review via Claude (Anthropic Messages API) ---
const CLAUDE_DEFAULT_MODEL = "claude-haiku-4-5-20251001"; // fast/cheap — matches the review task's cost profile
const CLAUDE_API_VERSION = "2023-06-01";

// Claude has no OpenAI-style response_format:{type:"json_object"} guarantee, so even with a
// strict "respond with ONLY JSON" system prompt it can occasionally wrap the object in a
// ```json ... ``` fence or add a stray sentence around it. Pulling out the first {...} block
// (rather than assuming the whole string is bare JSON) makes parsing robust to that without
// needing tool-use/function-calling machinery for what's a simple scoring response.
function extractJsonObject(text) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1] : text;
  const start = candidate.indexOf("{");
  const end = candidate.lastIndexOf("}");
  if (start === -1 || end === -1 || end < start) return candidate.trim();
  return candidate.slice(start, end + 1);
}

async function handleReview(req, res) {
  if (!ANTHROPIC_API_KEY) return sendJSON(res, 503, { error: "ANTHROPIC_API_KEY not configured on server" });

  const body = await readBody(req);
  const system = typeof body.system === "string" ? body.system : "Du är en svensk ämneslärare.";
  const user = body.user || {};
  const model = (body.model && String(body.model)) || CLAUDE_DEFAULT_MODEL;

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": CLAUDE_API_VERSION,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model,
        max_tokens: 1024,
        temperature: 0.2,
        system: system + " Svara ENDAST med ett giltigt JSON-objekt — ingen inledande eller avslutande text, inga markdown-kodblock.",
        messages: [
          { role: "user", content: JSON.stringify(user) }
        ]
      })
    });

    if (!r.ok) {
      const t = await r.text();
      return sendJSON(res, r.status, { error: "anthropic_error", detail: t });
    }
    const data = await r.json();
    const text = data?.content?.[0]?.text || "{}";
    let review;
    try { review = JSON.parse(extractJsonObject(text)); } catch { review = { summary_feedback: "Kunde inte tolka svaret från modellen." }; }

    // Track review submission
    trackReview(req, { user, review });

    return sendJSON(res, 200, { review });
  } catch (e) {
    return sendJSON(res, 500, { error: "fetch_failed", detail: e.message });
  }
}

// --- Static files (and index fallback) ---
async function serveStatic(req, res, urlObj) {
  let pathname = decodeURIComponent(urlObj.pathname);
  if (pathname === "/") pathname = "/index.html";

  // block direct access to packs; force API
  if (pathname.startsWith("/packs/")) {
    return sendJSON(res, 403, { error: "Use /api/pack endpoints" });
  }

  const full = safeJoin(PUBLIC_DIR, pathname);
  if (!full) return sendJSON(res, 400, { error: "Bad path" });

  try {
    const stat = await fsp.stat(full);
    if (stat.isDirectory()) {
      // try index.html inside
      const idx = path.join(full, "index.html");
      await fsp.access(idx);
      return pipeFile(res, idx);
    }
    return pipeFile(res, full);
  } catch {
    // SPA fallback -> index.html
    return pipeFile(res, path.join(PUBLIC_DIR, "index.html"));
  }
}
function pipeFile(res, file) {
  const ext = path.extname(file).toLowerCase();
  const type = ({
    ".html":"text/html; charset=utf-8",
    ".js":"text/javascript; charset=utf-8",
    ".css":"text/css; charset=utf-8",
    ".json":"application/json; charset=utf-8",
    ".png":"image/png", ".jpg":"image/jpeg", ".jpeg":"image/jpeg",
    ".svg":"image/svg+xml", ".ico":"image/x-icon"
  })[ext] || "application/octet-stream";
  res.writeHead(200, {"Content-Type": type});
  fs.createReadStream(file).pipe(res);
}

// --- API: check if the Claude API key is configured ---
async function handleConfig(res) {
  return sendJSON(res, 200, { hasClaude: !!ANTHROPIC_API_KEY });
}

// --- API: get analytics data ---
async function handleAnalytics(res) {
  // Convert Map data to plain objects for JSON
  const sessions = Array.from(analytics.sessions.values()).map(s => ({
    ...s,
    packsUsed: Array.from(s.packsUsed)
  }));

  const packUsage = Array.from(analytics.packUsage.entries()).map(([packId, count]) => ({
    packId,
    count
  })).sort((a, b) => b.count - a.count);

  // Convert pack performance data
  const packPerformance = {};
  analytics.packPerformance.forEach((packs, clientId) => {
    packPerformance[clientId] = {};
    packs.forEach((stats, packId) => {
      const accuracy = stats.totalAttempts > 0 ? (stats.correctAttempts / stats.totalAttempts) * 100 : 0;
      const avgTime = stats.totalAttempts > 0 ? stats.totalTime / stats.totalAttempts : 0;
      packPerformance[clientId][packId] = {
        ...stats,
        accuracy: accuracy.toFixed(1),
        avgTimePerQuestion: Math.round(avgTime)
      };
    });
  });

  // Calculate quiz statistics
  const recentQuizActivity = analytics.quizActivity.slice(-200);
  const quizStats = {
    totalAttempts: analytics.quizActivity.length,
    recentAccuracy: recentQuizActivity.length > 0
      ? ((recentQuizActivity.filter(q => q.isCorrect).length / recentQuizActivity.length) * 100).toFixed(1)
      : null
  };

  // Calculate time spent per pack per client
  const timeSpentByClient = {};
  analytics.packSessions.forEach(session => {
    if (session.action === 'end' && session.duration) {
      if (!timeSpentByClient[session.clientId]) {
        timeSpentByClient[session.clientId] = {};
      }
      if (!timeSpentByClient[session.clientId][session.packId]) {
        timeSpentByClient[session.clientId][session.packId] = 0;
      }
      timeSpentByClient[session.clientId][session.packId] += session.duration;
    }
  });

  // Calculate statistics
  const recentReviews = analytics.reviews.slice(-100); // Last 100 reviews
  const avgScores = recentReviews.length > 0 ? {
    correctness: recentReviews.reduce((sum, r) => sum + (r.scores.correctness || 0), 0) / recentReviews.length,
    clarity: recentReviews.reduce((sum, r) => sum + (r.scores.clarity || 0), 0) / recentReviews.length,
    completeness: recentReviews.reduce((sum, r) => sum + (r.scores.completeness || 0), 0) / recentReviews.length,
    technical: recentReviews.reduce((sum, r) => sum + (r.scores.technical || 0), 0) / recentReviews.length,
    overall: recentReviews.reduce((sum, r) => sum + (r.scores.overall || 0), 0) / recentReviews.length
  } : null;

  return sendJSON(res, 200, {
    sessions,
    packUsage,
    packPerformance,
    timeSpentByClient,
    quizStats,
    recentQuizActivity: recentQuizActivity.slice(-50),
    recentReviews,
    avgScores,
    totalSessions: sessions.length,
    totalReviews: analytics.reviews.length
  });
}

// --- API: track activity ---
async function handleTrackActivity(req, res) {
  const body = await readBody(req);
  const { type, packId, data } = body;

  try {
    if (type === 'quiz' || type === 'flashcard' || type === 'match') {
      trackQuizActivity(req, packId, {
        question: data.question,
        userAnswer: data.userAnswer,
        correctAnswer: data.correctAnswer,
        isCorrect: data.isCorrect,
        mode: type,
        timeTaken: data.timeTaken
      });
    } else if (type === 'session') {
      trackPackSession(req, packId, data.action, data.duration);
    }

    return sendJSON(res, 200, { success: true });
  } catch (e) {
    return sendJSON(res, 500, { error: "tracking_failed", detail: e.message });
  }
}

// --- HTTP router ---
const server = http.createServer(async (req, res) => {
  try {
    const urlObj = new URL(req.url, `http://${req.headers.host}`);

    // API routes
    if (req.method === "GET" && urlObj.pathname === "/api/config") {
      return handleConfig(res);
    }
    if (req.method === "GET" && urlObj.pathname === "/api/packs") {
      return handleListPacks(res);
    }
    if (req.method === "GET" && urlObj.pathname.startsWith("/api/pack/")) {
      const fname = urlObj.pathname.replace("/api/pack/", "");
      return handleGetPack(req, res, fname);
    }
    if (req.method === "POST" && urlObj.pathname === "/api/review") {
      return handleReview(req, res);
    }
    if (req.method === "GET" && urlObj.pathname === "/api/analytics") {
      return handleAnalytics(res);
    }
    if (req.method === "POST" && urlObj.pathname === "/api/track") {
      return handleTrackActivity(req, res);
    }

    // Static
    return serveStatic(req, res, urlObj);
  } catch (e) {
    console.error("Server error:", e);
    return sendJSON(res, 500, { error: "server_error", detail: e.message });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`✅ Test Prep server running at http://127.0.0.1:${PORT}`);
  console.log(`   Static: ${PUBLIC_DIR}`);
  console.log(`   Packs : ${PACKS_DIR} (list via GET /api/packs)`);
});