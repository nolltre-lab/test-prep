// server.js — zero-dependency Node server for Test Prep
// Node >= 18 required (built-in fetch).
// Reads OpenAI key from ENV OPENAI_API_KEY or ./config.json { "OPENAI_API_KEY": "sk-..." }

const http = require("http");
const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");
const { URL } = require("url");

const ROOT = __dirname;
const PUBLIC_DIR = ROOT;            // serve index.html and static files from here
const PACKS_DIR = path.join(ROOT, "packs");
const PORT = process.env.PORT ? Number(process.env.PORT) : 8787;

// --- Load config / API key ---
let OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const cfgPath = path.join(ROOT, "config.json");
if (!OPENAI_API_KEY && fs.existsSync(cfgPath)) {
  try {
    const cfg = JSON.parse(fs.readFileSync(cfgPath, "utf-8"));
    if (cfg.OPENAI_API_KEY) OPENAI_API_KEY = cfg.OPENAI_API_KEY;
    if (cfg.PORT && !process.env.PORT) console.warn("Tip: You can set PORT in config.json, but ENV wins.");
  } catch (e) {
    console.warn("Could not read config.json:", e.message);
  }
}
if (!OPENAI_API_KEY) {
  console.warn("\n⚠️  No OPENAI_API_KEY set. /api/review will return 503 until you add one.\n" +
               "   Set env var OPENAI_API_KEY or create config.json with { \"OPENAI_API_KEY\": \"sk-...\" }\n");
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
async function handleGetPack(res, fnameRaw) {
  const fname = path.basename(fnameRaw); // prevent traversal
  const full = safeJoin(PACKS_DIR, fname);
  if (!full || !full.toLowerCase().endsWith(".json")) {
    return sendJSON(res, 400, { error: "Bad file name" });
  }
  try {
    const txt = await fsp.readFile(full, "utf-8");
    const obj = JSON.parse(txt);
    return sendJSON(res, 200, obj);
  } catch (e) {
    return sendJSON(res, 404, { error: "Pack not found or invalid JSON", detail: e.message });
  }
}

// --- API: review via OpenAI ---
async function handleReview(req, res) {
  if (!OPENAI_API_KEY) return sendJSON(res, 503, { error: "OPENAI_API_KEY not configured on server" });

  const body = await readBody(req);
  const system = typeof body.system === "string" ? body.system : "Du är en svensk ämneslärare.";
  const user = body.user || {};
  const model = (body.model && String(body.model)) || "gpt-4o-mini";

  try {
    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: JSON.stringify(user) }
        ]
      })
    });

    if (!r.ok) {
      const t = await r.text();
      return sendJSON(res, r.status, { error: "openai_error", detail: t });
    }
    const data = await r.json();
    const text = data?.choices?.[0]?.message?.content || "{}";
    let review;
    try { review = JSON.parse(text); } catch { review = { summary_feedback: "Kunde inte tolka svaret från modellen." }; }
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

// --- API: check if OpenAI key is configured ---
async function handleConfig(res) {
  return sendJSON(res, 200, { hasOpenAI: !!OPENAI_API_KEY });
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
      return handleGetPack(res, fname);
    }
    if (req.method === "POST" && urlObj.pathname === "/api/review") {
      return handleReview(req, res);
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